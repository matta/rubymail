=begin
   Copyright (C) 2001, 2002 Matt Armstrong.  All rights reserved.

   Permission is granted for use, copying, modification, distribution,
   and distribution of modified versions of this work as long as the
   above copyright notice is included.
=end

module Mail

  # This is a module containing methods that know how deliver to
  # various kinds of message folder types.
  module Deliver

    @@mail_deliver_maildir_count = 0

    # Deliver +message+ to an mbox +filename+.
    #
    # The +each+ method on +message+ is used to get each line of the
    # message.  If the first line of the message is not an mbox
    # <tt>From_</tt> header, a fake one will be generated.
    #
    # The file named by +filename+ is opened for append, and +flock+
    # locking is used to prevent other processes from modifying the
    # file during delivery.  No ".lock" style locking is performed.
    # If that is desired, it should be performed before calling this
    # method.
    def deliver_mbox(filename, message)
      File.open(filename, File::WRONLY|File::APPEND|File::CREAT|File::SYNC,
		0600) { |f|
	f.flock(File::LOCK_EX)
	first = true
	message.each { |line|
	  if first
	    first = false
	    if line !~ /^From .*\d$/
              from = "From foo@bar  " + Time.now.asctime + "\n"
	      f << from
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

    # Delivery +message+ to a Maildir.
    #
    # See http://cr.yp.to/proto/maildir.html for a description of the
    # maildir mailbox format.  Its primary advantage is that it
    # requires no locks -- delivery and access to the mailbox can
    # occur at the same time.
    #
    # The +each+ method on +message+ is used to get each line of the
    # message.  If the first line of the message is an mbox
    # <tt>From_</tt> line, it is discarded.
    #
    # The filename of the successfully delivered message is returned.
    # Will raise exceptions on any kind of error.
    #
    # This method will attempt to create the Maildir if it does not
    # exist.
    def deliver_maildir(dir, message)
      require 'socket'

      # First, make the required directories
      new = File.join(dir, 'new')
      tmp = File.join(dir, 'tmp')
      [ dir, new, tmp, File.join(dir, 'cur') ].each { |d|
        begin
          Dir.mkdir(d, 0700)
        rescue Errno::EEXIST
          raise unless FileTest::directory?(d)
        end
      }

      sequence = @@mail_deliver_maildir_count
      @@mail_deliver_maildir_count = @@mail_deliver_maildir_count.next
      try_count = 1
      tmp_name = nil
      new_name = nil
      begin
        # Try to open the file in the 'tmp' directory up to 5 times
        f = begin
              name = sprintf("%d.%d_%d.%s", Time::now.to_i, Process::pid,
                             sequence, Socket::gethostname)

              tmp_name = File.join(tmp, name)
              new_name = File.join(new, name)

              File.open(tmp_name,
                        File::CREAT|File::EXCL|File::WRONLY|File::SYNC,
                        0600)
            rescue Errno::EEXIST
              raise if try_count >= 5
              sleep(2)
              try_count = try_count.next
              retry
            end

        begin
          # Write the message to the file
          first = true
          message.each { |line|
            if first
              first = false
              next if line =~ /From /
            end
            f << line
            f << "\n" unless line[-1] == ?\n
          }

          f.close
          f = nil

          # Link the tmp file to the new file
          File.link(tmp_name, new_name)
        ensure
          # Try to delete the tmp file
          begin
            File.delete(tmp_name) unless tmp_name.nil?
          rescue Errno::ENOENT
          end
        end
      ensure
        f.close unless f.nil?
      end

      new_name
    end

  end
end
