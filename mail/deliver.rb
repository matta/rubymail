#!/usr/bin/env ruby
#
#   Copyright (c) 2001 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

module Mail
  module Deliver

    # Deliver 'message' to an mbox 'filename'.  The 'each' method on
    # 'message' will be used to get each line of the message.  If the
    # first line of the message is not a "From " message, one will be
    # generated, either by calling the 'mbox_from' method on
    # 'message' or, if no get_sender method is available, by
    # generating one from foo@bar.
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
  end
end
