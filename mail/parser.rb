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
      message = @message_class.new
      parse_header(input, message)
      parse_body(input, message)
      message
    end

    private

    def parse_body(input, message)
      body = ""
      while line = input.gets
        body << line
      end
      message.body = body
    end

    # fixme, document methadology for this (RFC2822)
    FIELD_NAME = '[^\x00-\x1f\x7f-\xff :]+:';
    EXTRACT_FIELD_NAME_RE = /\A(#{FIELD_NAME})\s*/o

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
