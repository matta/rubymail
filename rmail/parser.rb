#!/usr/bin/env ruby
=begin
   Copyright (C) 2002 Matt Armstrong.  All rights reserved.

   Permission is granted for use, copying, modification,
   distribution, and distribution of modified versions of this work
   as long as the above copyright notice is included.
=end

require 'rmail/message'
require 'rmail/parser/multipart'

module RMail

  # The RMail::Parser class is responsible for parsing messages from
  # files.
  class Parser

    # Creates a new parser.  Messages of +message_class+ will be
    # created by the parser.  By default, the parser will create
    # RMail::Message objects.
    #
    # FIXME: document exactly the API +message_class+ must implement
    # in order to be functional.
    def initialize(message_class = RMail::Message)
      @message_class = message_class
    end

    # Parse a message from the IO object +io+ and return a new
    # message.
    def parse(input)
      parse_low(PushbackReader.new(input), 0)
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
      input = MultipartReader.
        new(input, message.header.param('content-type', 'boundary'))

      # Reach each part, adding it to this entity as appropriate.
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

      end
    end

    # fixme, document methadology for this (RFC2822)
    FIELD_NAME = '[^\x00-\x1f\x7f-\xff :]+:';
    EXTRACT_FIELD_NAME_RE = /\A(#{FIELD_NAME}) */o

    def parse_header(input, message)
      data = nil
      header = nil
      pushback = nil
      while chunk = input.read
        data ||= ''
        data << chunk
        if data[0] == ?\n
          header = nil
          data[0, 1] = ''
          rest = data
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
        elsif field =~ EXTRACT_FIELD_NAME_RE
          message.header.add($1, $'.chomp("\n"))
        end
      }
    end
  end
end
