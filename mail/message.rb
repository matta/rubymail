#!/usr/bin/env ruby
#
#   Copyright (c) 2001 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

require 'mail/header.rb'

module Mail

  # The Mail::Message provides a way to read a RFC2822 message from an
  # input stream and manipulate the header and body.
  class Message

    # Create a new Mail::Message.
    #
    # If +input+ is not nil, <tt>input.each_line</tt> will be used to
    # retrieve the message.
    def initialize(input)
      @header = Mail::Header.new(input)
      @body = []
      unless input.nil?
	input.each_line { |ln|
	  @body.push(ln)
	}
      end
    end

    # Returns the body of the message as an array of strings.
    #
    # Each string will include a trailing newline (<tt>\n</tt>).
    #
    # See also #header.
    def body()
      return @body
    end

    # Returns the Mail::Header object.
    #
    # See also #body.
    def header()
      return @header
    end

    # Returns the entire message in a single string.
    def to_s()
      s = @header.to_s + "\n" + @body.join('')
    end

    # Call the supplied block for each line of the message.  Each line
    # will contain a trailing newline (<tt>\n</tt>).
    def each()
      @header.to_s.each("\n") {|line|
	yield line
      }
      yield "\n"
      @body.each {|line|
	yield line
      }
    end

  end
end
