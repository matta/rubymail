#!/usr/bin/env ruby
#--
#   Copyright (c) 2002 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

require 'rmail/parser/pushbackreader'

module RMail
  module Mailbox

    # Class that can parse Unix mbox style mailboxes.  These
    # mailboxes separate individual messages with a line beginning
    # with the string "From ".
    #
    # Typical usage:
    #
    #  File.open("file.mbox") { |f|
    #    reader = RMail::Mailbox::MBoxReader.new(f)
    #    while ! reader.eof
    #      process_message(reader.read(nil))
    #      reader.next
    #    end
    #  }
    #
    # Or see RMail::Mailbox.parse_mbox for a more convenient
    # interface.
    #
    class MBoxReader < RMail::Parser::PushbackReader

      # Creates a new MBoxReader that reads from `input' with lines
      # that end with `line_separator'.
      #
      # `input' can either be an IO source (an object that responds to
      # the "read" method in the same way as a standard IO object) or
      # a String.
      #
      # `line_separator' defaults to $/, and useful values are
      # probably limited to "\n" (Unix) and "\r\n" (DOS/Windows).
      def initialize(input, line_separator = $/)
        super(input)
        @end_of_message = false
        @chunk_minsize = 0
        @line_separator = line_separator

        # This regexp will match a From_ header, or some prefix.
        @partial_from_re = RMail::Parser::PushbackReader.
          maybe_contains_re("#{@line_separator}From ")

        # This regexp will match an entire From_ header.
        @entire_from_re = /\A#{@line_separator}From .*?#{@line_separator}/
      end

      # Reads some data from the current message and returns it.  The
      # `size' argument is just a suggestion, and the returned string
      # can be larger or smaller.  When `size' is nil, then the entire
      # message is returned.
      #
      # Once all data from the current message has been read, #read
      # returns nil and #next must be called to begin reading from the
      # next message.  You can use #eof to tell if there is any more
      # data to be read from the input source.
      def read(size = @chunk_size)
        chunk = nil
        if size.nil?
          # Handle reading a whole message if given a nil chunk size.
          while temp = read(@chunk_size)
            if chunk
              chunk << temp
            else
              chunk = temp
            end
          end
        else
          if !@end_of_message and chunk = super(size)
            # Read at least @chunk_minsize bytes.
            while chunk.length < @chunk_minsize && more = super(size)
              chunk << more
            end
            if match = @partial_from_re.match(chunk)
              # We matched what might be a From_ separator.  Separate
              # the chunk into what came before and what came after it.
              mbegin = match.begin(0)
              rest = chunk[mbegin .. -1]

              if @entire_from_re =~ rest
                # We've got a full From_ line, so set the end of message
                # flag and get rid of the line separator present just
                # before the From_.
                @end_of_message = true
                @chunk_minsize = 0
                rest[0, @line_separator.length] = "" # painful
              else
                # Make sure we read more than just the pushback.
                @chunk_minsize = rest.length + 1
              end

              # Return the whole chunk with a partially matched From_
              # when there is nothing further to read.
              unless ! @end_of_message && eof
                # Otherwise, push back the From_ and return the
                # pre-match.
                pushback(rest)
                if mbegin == 0 and @end_of_message
                  chunk = nil
                else
                  chunk = chunk[0, mbegin]
                end
              end

            end
          end
        end
        return chunk
      end

      # Advances to the next message to be read.  Call this after
      # #read returns nil.
      #
      # Note: Once #read returns nil, you can call #eof before or
      # after calling #next to tell if there actually is a next
      # message to read.
      def next
        @end_of_message = false
      end

    end
  end
end
