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
  # files or strings.
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
        puts "parse_body: body #{data.inspect}" if $DEBUG
        message.body = data
      end
    end

    def parse_multipart_body(input, message, depth)
      input = MultipartReader.
        new(input, message.header.param('content-type', 'boundary'))
      input.chunk_size = @chunk_size if @chunk_size

      # Ensure that message.multipart? returns true even if there are
      # no body parts.
      message.body = []

      # Reach each part, adding it to this entity as appropriate.
      while input.next_part
        # Strip the newline that the multipart reader left at the
        # end of each boundary line.  We skip doing this for preamble
        # parts because they do not begin with a boundary line.
        if !input.preamble?
          while peek = input.read
            if peek.length > 0
              puts "parse_multipart_body: " +
                "depth #{depth} peek #{peek.inspect}" if $DEBUG
              peek[0,1] = ''
              input.pushback(peek)
              break
            end
          end
        end

        if input.preamble? || input.epilogue?
          data = nil
          while chunk = input.read
            data ||= ''
            data << chunk
          end
          if data and data.length > 0
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
      puts "parse_header: header #{header.inspect} rest #{rest.inspect}" if
        $DEBUG
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

if $0 == __FILE__
  require 'pp'
  File.open("../tests/data/transparency/message.1") {|f|
    p = RMail::Parser.new
    p.chunk_size = 1024 * 64
    pp p.parse(f)
  }
end
