#--
#   Copyright (C) 2002, 2003 Matt Armstrong.  All rights reserved.
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
# Implements the RMail::Parser class.

require 'rmail/message'
require 'rmail/parser/multipart'

module RMail

  # The RMail::Parser class creates RMail::Message objects from Ruby
  # IO objects or strings.
  #
  # To parse from a string:
  #   message = RMail::Parser.read(the_string)
  #
  # To parse from an IO object:
  #   message = File.open('my-message') { |f|
  #     RMail::Parser.read(f)
  #   }
  #
  # You can also parse from STDIN, etc.
  #   message = RMail::Parser.read(STDIN)
  #
  # In all cases, the parser consumes all input.
  class Parser

    # This exception class is thrown when the parser encounters an
    # error.
    #
    # Note: the parser tries hard to never throw exceptions -- this
    # error is thrown only when the API is used incorrectly and not on
    # invalid input.
    class Error < StandardError; end

    # Creates a new parser.  Messages of +message_class+ will be
    # created by the parser.  By default, the parser will create
    # RMail::Message objects.
    #
    # FIXME: document exactly the API +message_class+ must implement
    # in order to be functional.
    def initialize(message_class = RMail::Message)
      @message_class = message_class
      @chunk_size = nil
    end

    # Parse a message from the IO object +io+ and return a new
    # message.  The +io+ object can also be a string.
    def parse(input)
      reader = PushbackReader.new(input)
      reader.chunk_size = @chunk_size if @chunk_size
      parse_low(reader, 0)
    end

    # Change the chunk size used to read the message.  This is useful
    # mostly for testing.
    attr_accessor :chunk_size

    # Parse a message from the IO object +io+ and return a new
    # message.  The +io+ object can also be a string.  This is just
    # shorthand for:
    #
    #   RMail::Parser.new.parse(io)
    def Parser.read(input)
      Parser.new.parse(input)
    end

    private

    # Parse a message from the IO object +io+ and return a new
    # message.
    def parse_low(input, depth)
      message = @message_class.new
      parse_header(input, message)
      parse_body(input, message, depth)
      message
    end

    def parse_body(input, message, depth)
      if message.header.param('content-type', 'boundary') &&
          message.header.media_type == "multipart" &&
          (depth > 0 || message.header['mime-version'] =~ /\b1\.0\b/)
        parse_multipart_body(input, message, depth)
      else
        data = nil
        while chunk = input.read
          data ||= ''
          data << chunk
        end
        message.body = data
      end
    end

    def parse_multipart_body(input, message, depth)
      boundary = message.header.param('content-type', 'boundary')
      input = MultipartReader.new(input, boundary)
      input.chunk_size = @chunk_size if @chunk_size

      # Ensure that message.multipart? returns true even if there are
      # no body parts.
      message.body = []

      # Reach each part, adding it to this entity as appropriate.
      delimiters = []
      while input.next_part
        if input.preamble? || input.epilogue?
          data = nil
          while chunk = input.read
            data ||= ''
            data << chunk
          end
          if data
            if input.preamble?
              message.preamble = data
            else
              message.epilogue = data
            end
          end
        else
          message.add_part(parse_low(input, depth + 1))
        end
        delimiters << (input.delimiter || "") unless input.epilogue?
        message.set_delimiters(delimiters, boundary)
      end
    end

    def parse_header(input, message)
      data = nil
      header = nil
      pushback = nil
      while chunk = input.read
        data ||= ''
        data << chunk
        if data[0] == ?\n
          # A leading newline in the message is seen when parsing the
          # parts of a multipart message.  It means there are no
          # headers.  The body part starts directly after this
          # newline.
          rest = data[1..-1]
        else
          header, rest = data.split("\n\n", 2)
        end
        break if rest
      end
      input.pushback(rest)
      parse_header_string(header, message) if header
    end

    def parse_header_string(string, message)
      first = true
      string.split(/\n(?!\s)/).each { |field|
        if first && field =~ /^From /
          message.header.mbox_from = field
        else
          message.header.add_raw(field)
        end
      }
    end
  end
end
