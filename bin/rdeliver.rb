#!/usr/bin/env ruby
#--
#   Copyright (C) 2001, 2002 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification, distribution,
#   and distribution of modified versions of this work as long as the
#   above copyright notice is included.
#
#++
# This script serves as an example of how you can use the Mail::LDA
# class to perform mail delivery.  You can also use this script as a
# fully functioning mail filter.
#
# This script is a basic mail local delivery agent (LDA) that can be
# used in place of procmail, maildrop, etc. in a user's .forward or
# .qmail file.  The user supplies a delivery script that is written in
# Ruby, which avoids the limitations of the crippled mini-languages so
# often used in other LDA programs.
#
# === Usage
#
# rdeliver is invoked from the command line using:
#
#   % rdeliver <options> [script]
#
# The script argument is optional.  If omitted the script will look
# for a file called .rdeliver in the home directory.
#
# Options are:
#
# <tt>--load-path</tt>::     Prepend the given directory to ruby's
#                            load path.
#
# <tt>--log</tt> <i>filename</i>::   Log to the given <i>filename</i>.  If no
#                                    log is specified, no logging occurs.
#
# <tt>--home</tt> <i>directory</i>::  Specify the home <i>directory</i>.
#                                     rdeliver will change to this directory
#                                     before reading and writing any files.
#                                     The home directory defaults to
#                                     the value of the +HOME+ or +LOGDIR+
#                                     environment variable.
# === Delivery Script
#
# The delivery script runs in the context of a class called Deliver
# (in contrast, most ruby scripts run in the context of the Object
# class).  So any methods added with +def+ will be added to the
# Deliver class.
#
# A minimal delivery script would be:
#
#   def main
#     lda.save('inbox')
#   end
#
# This code defines a Deliver#main method that saves the mail into an
# mbox style mailbox.
#
# The only API the Deliver script has is the #lda method.  This
# retrieves the Mail::LDA object associated with the current message.
# Using the API of the Mail::LDA object, you can access and modify the
# message body and headers, defer or reject the message delivery, and
# deliver into various mailbox formats.
#
# See also Mail::LDA and Deliver.
#
# === Installation
#
# Assuming you have the RubyMail mail classes installed, you typically
# have to put something like this in your .forward file:
#
#    |"/usr/local/bin/rdeliver --log /home/you/.rlog"
#
# This will call rdeliver for each new message you get, and log to
# <tt>/home/you/.rlog</tt>.
#
# === Catastrophic Errors
#
# The rdeliver script is very careful with errors.  If there is any
# problem, it logs the error to the log file you specify.  But if you
# do not specify a log file, or the error occurs before the log file
# is opened, a record of the error is placed in a file called
# CATASTROPHIC_DELIVERY_FAILURE in the home directory.  If that fails,
# the error information is printed to the standard output in the hopes
# that it will be part of a bounce message.  In all cases, the exit
# code 75 is returned, which tells the MTA to re-try the delivery
# again.

def print_exception(file, exception) # :nodoc:
  file.puts("Exception:\n    " +
	    exception.inspect + "\n")
  file.puts "Backtrace:\n"
  exception.backtrace.each { |line|
    file.puts "    " + line + "\n"
  }
end

# Try to get to home dir, in prep for possibly writing
# CATASTROPHIC_DELIVERY_FAILURE
not_in_home_dir_exception = nil
begin
  Dir.chdir
rescue Exception
  not_in_home_dir_exception = $!
end

begin
  $SAFE = 1
  require 'getoptlong'

  parser = GetoptLong.new\
  (['--load-path', '-I', GetoptLong::REQUIRED_ARGUMENT],
   ['--log', '-l', GetoptLong::REQUIRED_ARGUMENT],
   ['--home', '-h', GetoptLong::REQUIRED_ARGUMENT])
  parser.quiet = true
  log = nil
  parser.each_option do |name, arg|
    case name
    when '--home'
      Dir.chdir(arg.untaint)
      not_in_home_dir_exception = nil
    when '--log'
      log = arg.untaint
    when '--load-path'
      $LOAD_PATH.unshift(arg.untaint)
    else
      raise "don't know about argument #{name}"
    end
  end

  config = ARGV.shift
  config ||= '.rdeliver'
  config = File.expand_path(config).untaint

  raise "extra arguments passed to #{$0}: #{ARGV.inspect}" unless ARGV.empty?

  require 'mail/lda'

  begin

    # The Deliver class used by the bin/rdeliver.rb script to provide
    # a place for the user's delivery script to run.  The user's
    # delivery script executes in the context of this class, so
    # methods defined with +def+ do not pollute the global namespace.
    # The user is expected to define a #main method that will be
    # called to deliver the mail.
    #
    # See also bin/rdeliver.rb
    class Deliver
      def initialize(lda) # :nodoc:
        @__MAIL_LDA__ = lda
      end
      # Return the Mail::LDA object for the current message.  This is
      # all you need to retrieve, modify, and deliver the message.
      def lda
        @__MAIL_LDA__
      end
      # This method is called by bin/rdeliver.rb after the Deliver
      # object is instantiated.  A default implementation that merely
      # defers the delivery is provided, but the user is expected to
      # replace this with a version that delivers the mail to the
      # proper location.
      def main
        lda.defer('no deliver method specified in configuration file')
      end
    end
    Mail::LDA.process(STDIN, log) { |lda|
      eval(IO.readlines(config, nil)[0].untaint,
           Deliver.module_eval('binding()'),
           config)
      Deliver.new(lda).main
    }
  rescue Mail::LDA::DeliveryComplete => exception
    exit(Mail::LDA.exitcode(exception))
  end

  raise "Script should never get here."

rescue Exception => exception
  if exception.class <= SystemExit
    raise exception		# normal exit
  else
    # Be nice and stick the last delivery failure due to a catastrophic
    # situation in home/CATASTROPHIC_DELIVERY_FAILURE
    begin
      unless not_in_home_dir_exception.nil?
	raise not_in_home_dir_exception
      end
      File.open("CATASTROPHIC_DELIVERY_FAILURE", "w") { |file|
	print_exception(file, exception)
      }
    rescue Exception => another_exception
      # In the event that the above doesn't happen, we write the error
      # to stdout and hope the mailer includes it in the bounce that
      # will eventually occur.
      print_exception(STDOUT, exception)
      puts "Failed writing CATASTROPHIC_DELIVERY_FAILURE because:"
      print_exception(STDOUT, another_exception)
    ensure
      exit 75			# EX_TMPFAIL
    end
  end
end
