#--
#   Copyright (c) 2002, 2003 Matt Armstrong.  All rights reserved.
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
# Implements the RMail::Mailbox::MBoxReader class.

require 'rmail/parser/pushbackreader'

module RMail
  module Mailbox

    # Class that can parse Unix mbox style mailboxes.  These mailboxes
    # separate individual messages with a line beginning with the
    # string "From ".
    #
    # Typical usage:
    #
    #  File.open("file.mbox") { |file|
    #    RMail::Mailbox::MBoxReader.new(file).each_message { |input|
    #      message = RMail::Parser.read(input)
    #      # do something with the message
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
        @sep = line_separator
        @tail = nil

        # This regexp will match a From_ header, or some prefix.
        re_string = RMail::Parser::PushbackReader.
          maybe_contains_re("#{@sep}From ")
        @partial_from_re = Regexp.new(re_string)

        # This regexp will match an entire From_ header.
        @entire_from_re = /\A#{@sep}From .*?#{@sep}/
      end

      alias_method :parent_read_chunk, :read_chunk

      # Reads some data from the current message and returns it.  The
      # `size' argument is just a suggestion, and the returned string
      # can be larger or smaller.  When `size' is nil, then the entire
      # message is returned.
      #
      # Once all data from the current message has been read, #read
      # returns nil and #next must be called to begin reading from the
      # next message.  You can use #eof to tell if there is any more
      # data to be read from the input source.
      def read_chunk(size)
        chunk = read_chunk_low(size)
        if chunk
          if chunk.length > @sep.length
            @tail = chunk[-@sep.length .. -1]
          else
            @tail ||= ''
            @tail << chunk
          end
        elsif @tail
          if @tail[-@sep.length .. -1] != @sep
            chunk = @sep
          end
          @tail = nil
        end
        chunk
      end

      # Advances to the next message to be read.  Call this after
      # #read returns nil.
      #
      # Note: Once #read returns nil, you can call #eof before or
      # after calling #next to tell if there actually is a next
      # message to read.
      def next
        @end_of_message = false
        @tail = nil
      end

      alias_method :parent_eof, :eof

      # Returns true if the next call to read_chunk will return nil.
      def eof
        parent_eof and @tail.nil?
      end

      # Yield self until eof, calling next after each yield.
      #
      # This method makes it simple to read messages successively out
      # of the mailbox.  See the class description for a code example.
      def each_message
        while !eof
          yield self
          self.next
        end
      end

      private

      def read_chunk_low(size)
        return nil if @end_of_message
        if chunk = parent_read_chunk(size)
          # Read at least @chunk_minsize bytes.
          while chunk.length < @chunk_minsize && more = parent_read_chunk(size)
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
              rest[0, @sep.length] = "" # painful
            else
              # Make sure that next time we read more than just the
              # pushback.
              @chunk_minsize = rest.length + 1
            end

            # Return the whole chunk with a partially matched From_
            # when there is nothing further to read.
            unless ! @end_of_message && parent_eof
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
        return chunk
      end
    end
  end
end
