#!/usr/bin/env ruby
#
#   Copyright (c) 2001 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

module Mail

  # This is a module containing methods that know how deliver to
  # various kinds of message folder types.
  module Deliver

    # Deliver +message+ to an mbox +filename+.
    #
    # The +each+ method on +message+ is used to get each line of the
    # message.  If the first line of the message is not an mbox
    # <tt>From_</tt> header, one will be generated, either by calling
    # the <tt>mbox_from</tt> method on +message+ or, generating a fake
    # one.
    #
    # The file named by +filename+ is opened for append, and +flock+
    # locking is used to prevent other processes from modifying the
    # file during delivery.  No ".lock" style locking is performed.
    # If that is desired, it should be performed before calling this
    # method.
    #
    # FIXME: this method really should take a generic "lock me" style
    # object that takes a file and filename, with the default simply
    # performing flock locking.
    def deliver_mbox(filename, message)
      File.open(filename, File::WRONLY|File::APPEND|File::CREAT, 0600) { |f|
	f.flock(File::LOCK_EX)
	first = true
	message.each { |line|
	  if first
	    first = false
	    if line !~ /^From .*\d$/
	      if message.respond_to?(:mbox_from)
		from = message.mbox_from
	      else
		from = "From foo@bar  " + Time.now.asctime + "\n"
	      end
	      from += "\n" unless from[-1] == ?\n
	      f << from
	      if line =~ /^From / then next end
	    end
	  elsif line =~ /^From /
	    f << '>'
	  end
	  f << line
	  f << "\n" unless line[-1] == ?\n
	}
	f << "\n"
	f.flush
	f.flock(File::LOCK_UN)
      }
    end

    # Deliver +message+ to a pipe.
    #
    # The supplied +command+ is run in a sub process, and
    # <tt>message.each</tt> is used to get each line of the message
    # and write it to the pipe.
    #
    # This method captures the <tt>Errno::EPIPE</tt> and ignores it,
    # since this exception can be generated when the command exits
    # before the entire message is written to it (which may or may not
    # be an error).
    #
    # The caller can (and should!) examine <tt>$?</tt> to see the exit
    # status of the pipe command.
    def deliver_pipe(command, message)
      begin
	IO.popen(command, "w") { |io|
	  message.each { |line|
	    io << line
	    io << "\n" unless line[-1] == ?\n
	  }
	}
      rescue Errno::EPIPE
	# Just ignore.
      end
    end
  end
end
