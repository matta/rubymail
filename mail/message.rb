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
      @epilogue = nil
      @preamble = nil
    end

    # Test if this message is structured exactly the same as the other
    # message.  This is useful mainly for testing.
    def ==(other)
      @preamble == other.preamble &&
        @epilogue == other.epilogue &&
        @header == other.header &&
        @body == other.body
    end

    # Returns the body of the message as a string.
    #
    # See also #header.
    def body
      return @body
    end

    # Sets the body of the message to the given value.  It should
    # either be a string or an array of parts.
    def body=(s)
      @body = s
    end

    # Returns the Mail::Header object.
    #
    # See also #body.
    def header()
      return @header
    end

    # Return true if the message consists of multiple parts.
    def multipart?
      @body.is_a?(Array)
    end

    # Add a part to the message.
    def add_part(part)
      if @body.nil?
	@body = [part]
      elsif @body.is_a?(Array)
        @body.push(part)
      else
	@body = [@body, part]
      end
    end

    # Decode the body of this message.
    #
    # This only works when the message is not a multipart.
    def decode
      raise TypeError, "Can not decode a multipart message." if multipart?
      case header.fetch('content-transfer-encoding', '7bit').strip.downcase
      when 'quoted-printable'
        Utils.quoted_printable_decode(@body)
      when 'base64'
        Utils.base64_decode(@body)
      else
        @body
      end
    end

    # Get the indicated part from a multipart message.
    def part(i)
      raise TypeError,
        "Can not get part on a single part message." unless multipart?
      @body[i]
    end

    # Access the epilogue string for this message.
    attr :epilogue, true

    # Access the preamble string for this message.
    attr :preamble, true

    # Returns the entire message in a single string.
    def to_s()
      require 'mail/serialize'
      Serialize.new('').serialize(self)
    end

    # Return each part of this message
    #
    # FIXME: not tested
    def each_part
      raise TypeError, "not a multipart message" unless multipart?
      @body.each do |part|
        yield part
      end
    end

    # Call the supplied block for each line of the message.  Each line
    # will contain a trailing newline (<tt>\n</tt>).
    def each()
      # FIXME: this is incredibly inefficient!  The only users of this
      # is Mail::Deliver -- get them to use a Mail::Serialize object.
      to_s.each("\n") { |line|
        yield line
      }
    end

  end
end
