=begin
   Copyright (C) 2001, 2002 Matt Armstrong.  All rights reserved.

   Permission is granted for use, copying, modification, distribution,
   and distribution of modified versions of this work as long as the
   above copyright notice is included.
=end

require 'mail/header.rb'

module Mail

  # The Mail::Message provides a way to read a RFC2822 message from an
  # input stream and manipulate the header and body.
  class Message

    # Create a new, empty, Mail::Message.
    def initialize
      @header = Mail::Header.new
      @body = nil
    end

    # Returns the body of the message as a string.
    #
    # See also #header.
    def body
      return @body
    end

    # Sets the body of the message as a string.
    def body=(s)
      raise TypeError, "not a string" unless s.instance_of?(String)
      @body = s
    end

    # Returns the Mail::Header object.
    #
    # See also #body.
    def header()
      return @header
    end

    # Returns the entire message in a single string.
    def to_s()
      s = @header.to_s + "\n"
      unless @body.nil?
        s << @body
        s << '\n' unless @body[-1] == ?\n
      end
      s
    end

    # Call the supplied block for each line of the message.  Each line
    # will contain a trailing newline (<tt>\n</tt>).
    def each()
      @header.to_s.each("\n") {|line|
	yield line
      }
      yield "\n"
      @body.each_line {|line|
	yield line
      } unless @body.nil?
    end

  end
end
