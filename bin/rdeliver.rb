#!/usr/bin/env ruby
=begin
   Copyright (C) 2001, 2002 Matt Armstrong.  All rights reserved.

   Permission is granted for use, copying, modification, distribution,
   and distribution of modified versions of this work as long as the
   above copyright notice is included.
=end

# This script is an example of how to use Mail::LDA to create a
# mail delivery agent.

def print_exception(file, exception)
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

  raise "extra arguments passed to #{$0}: #{ARGV.inspect}" unless ARGV.empty?

  require 'mail/lda'

  begin
    Mail::LDA.process(STDIN, log) { |lda|
      $lda = lda
      load(File.expand_path(config).untaint)
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
