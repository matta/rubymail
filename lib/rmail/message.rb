#--
#   Copyright (C) 2001, 2002, 2003 Matt Armstrong.  All rights
#   reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The name of the author may not be used to endorse or promote products
#    derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN
# NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
# TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#++
# Implements the RMail::Message class.

require 'rmail/header.rb'

module RMail

  # The RMail::Message is an object representation of a standard
  # Internet email message, including MIME multipart messages.
  #
  # An RMail::Message object represents a message header (held in the
  # contained RMail::Header object) and a message body.  The message
  # body may either be a single String for single part messages or an
  # Array of RMail::Message objects for MIME multipart messages.
  class Message

    # Create a new, empty, RMail::Message.
    def initialize
      @header = RMail::Header.new
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

    # Returns the body of the message as a String or Array.
    #
    # If #multipart? returns true, it will be an array of
    # RMail::Message objects.  Otherwise it will be a String.
    #
    # See also #header.
    def body
      return @body
    end

    # Sets the body of the message to the given value.  It should
    # either be a String or an Array of RMail:Message objects.
    def body=(s)
      @body = s
    end

    # Returns the RMail::Header object.
    #
    # See also #body.
    def header()
      return @header
    end

    # Return true if the message consists of multiple parts.
    def multipart?
      @body.is_a?(Array)
    end

    # Add a part to the message.  After this message is called, the
    # #multipart? method will return true and the #body method will
    # #return an array of parts.
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
    # If the body of this message is encoded with
    # <tt>quoted-printable</tt> or <tt>base64</tt>, this function will
    # decode the data into its original form and return it as a
    # String.  If the body is not encoded, it is returned unaltered.
    #
    # This only works when the message is not a multipart.  The
    # <tt>Content-Transfer-Encoding:</tt> header field is consulted to
    # determine the encoding of the body part.
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

    # Access the epilogue string for this message.  The epilogue
    # string is relevant only for multipart messages.  It is the text
    # that occurs after all parts of the message and is generally nil.
    attr :epilogue, true

    # Access the preamble string for this message.  The preamble
    # string is relevant only for multipart messages.  It is the text
    # that occurs just before the first part of the message, and is
    # generally nil or simple English text describing the nature of
    # the message.
    attr :preamble, true

    # Returns the entire message in a single string.  This uses the
    # RMail::Serialize class.
    def to_s()
      require 'rmail/serialize'
      RMail::Serialize.new('').serialize(self)
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
      # is RMail::Deliver -- get them to use a RMail::Serialize object.
      to_s.each("\n") { |line|
        yield line
      }
    end

    # This is used by the RMail::Parser to set the MIME multipart
    # delimiter strings found in the message.  These delimiters are
    # then used when serializing the message again.
    #
    # Normal uses of RMail::Message will never use this method, and so
    # it is left undocumented.
    def set_delimiters(delimiters, boundary) # :nodoc:
      raise TypeError, "not a multipart message" unless multipart?
      raise ArgumentError, "delimiter array wrong size" unless
        delimiters.length == @body.length + 1
      @delimiters = delimiters.to_ary
      @delimiters_boundary = boundary.to_str
    end

    # This is used by the serializing functions to retrieve the MIME
    # multipart delimiter strings found while parsing the message.
    # These delimiters are then used when serializing the message
    # again.
    #
    # Normal uses of RMail::Message will never use this method, and so
    # it is left undocumented.
    def get_delimiters          # :nodoc:
      unless multipart? and @delimiters and @delimiters_boundary and
          @delimiters.length == @body.length + 1 and
          header.param('content-type', 'boundary') == @delimiters_boundary
        @delimiters = nil
        @delimiters_boundary = nil
      end
      [ @delimiters, @delimiters_boundary ]
    end

  end
end
