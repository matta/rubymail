#!/usr/bin/env ruby
#
#   Copyright (c) 2001 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#


# This is a simple wrapper script around the real delivery script.
# This script catches all possible exceptions and returns EX_TEMPFAIL
# if anything but SystemExit is thrown.  This makes it harder for
# random errors to cause a bounce.

begin
  $SAFE = 1
  
  # Find the deliver script through $0, which means this script will have
  # to be envoked with a fully qualified path in the .forward.
  dirname = File.dirname($0)
  if dirname !~ %r{^/}
    raise <<EOF
I (#{$0}) can not find the fully qualified
path to myself.  Most likely, you have not called
me with a fully qualified path name.
EOF
 end
  dirname.untaint
  $LOAD_PATH.unshift(dirname)
  load(File.join(dirname, 'main.rb'), true)
rescue Exception => exception
  if exception.class <= SystemExit
    raise exception		# normal exit
  else
    # Be nice and stick the last delivery failure due to a catastrophic
    # situation in ~/CATASTROPHIC_DELIVERY_FAILURE
    begin
      Dir.chdir
      File.open("CATASTROPHIC_DELIVERY_FAILURE", "w") { |file|
	file.puts "Exception:\n" + exception + "\n"
	file.puts "Backtrace:\n" + exception.backtrace.join("\n")
      }
    rescue Exception => another_exception
      # In the event that the above doesn't happen, we write the error
      # to stdout and hope the mailer includes it in the bounce that
      # will eventually occur.
      puts "uncaught exception:"
      puts exception
      puts "backtrace:"
      puts exception.backtrace.join("\n")
      puts "could not write to ~/CATASTROPHIC_DELIVERY_FAILURE:"
      puts another_exception
      puts "backtrace:"
      puts another_exception.backtrace.join("\n")
    end
    exit 75			# EX_TMPFAIL
  end
end
