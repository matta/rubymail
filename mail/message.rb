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
  class Message

    # Create a new Mail::Message.  Input is read if it is not nil.
    def initialize(input = $<)
      @header = Mail::Header.new(input)
      @body = []
      unless input.nil?
	input.each_line { |ln|
	  @body.push(ln)
	}
      end
    end

    # Returns the body of the message
    def body()
      return @body
    end

    # Returns the Mail::Header object
    def header()
      return @header
    end

    # Returns the entire message as a string
    def to_s()
      s = @header.to_s + "\n" + @body.join('')
    end

    # Iterate over every line of the message
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
