#!/usr/bin/env ruby
=begin
   Copyright (C) 2002 Matt Armstrong.  All rights reserved.

   Permission is granted for use, copying, modification,
   distribution, and distribution of modified versions of this work
   as long as the above copyright notice is included.
=end

require 'mail/message'

module Mail

  # The Mail::Parser class is responsible for parsing messages from
  # files.
  class Parser

    # Creates a new parser.  Messages of +message_class+ will be
    # created by the parser.  By default, the parser will create
    # Mail::Message objects.
    #
    # FIXME: document exactly the API +message_class+ must implement
    # in order to be functional.
    def initialize(message_class = Mail::Message)
      @message_class = message_class
    end

    # Parse a message from the IO object +io+ and return a new
    # message.
    def parse(input)
      parse_low(input, 0)
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
        data = ''
        while line = input.gets
          data << line
        end
        if data.length == 0
          data = nil
        elsif depth > 0
          # If we're parsing a multipart entity, get rid of the last
          # end of line terminator, since it is actually part of the
          # part separation boundary.
          data.chomp!("\n")
        end
        message.body = data
      end
    end

    def parse_multipart_body(input, message, depth)
      require 'mail/parser/multipart'

      input = Mail::Parser::Multipart.
        new(input, message.header.param('content-type', 'boundary'))

      # Reach each part, adding it to this entity as appropriate.
      while input.next_part

        if input.preamble? || input.epilogue?
          data = nil
          while line = input.gets
            data ||= ''
            data << line
          end
          if data
            data.chomp!("\n") unless input.epilogue? && depth == 0
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
      value = nil
      name = nil
      first = true
      while line = input.gets
	if value
          if line =~ /\A[ \t]+/
            value += line
            next
          else
            message.header.add(name, value)
            name = nil
            value = nil
          end
	end

        if first && line =~ /^From /
          message.header.mbox_from = line
        else
          case line
          when EXTRACT_FIELD_NAME_RE
            name = $1
            value = $'
          when /^$/
            break
          else
            name = nil
            value = nil
          end
        end
        first = false
      end
      message.header.add(name, value) if value
    end

  end

end
