#--
#   Copyright (C) 2002, 2003, 2004 Matt Armstrong.  All rights reserved.
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
# Implements the RMail::Parser::MultipartReader class.

module RMail
  class Parser

    require 'rmail/parser/pushbackreader'

    # A simple interface to facilitate parsing a multipart message.
    #
    # The typical RubyMail user will have no use for this class.
    # Although it is an example of how to use a PushbackReader, the
    # typical RubyMail user will never use a PushbackReader either.
    # ;-)
    class MultipartReader < PushbackReader # :nodoc:

      # Creates a MIME multipart parser.
      #
      # +input+ is an object supporting a +read+ method that takes one
      # argument, a suggested number of bytes to read, and returns
      # either a string of bytes read or nil if there are no more
      # bytes to read.
      #
      # +boundary+ is the string boundary that separates the parts,
      # without the "--" prefix.
      #
      # This class is a suitable input source when parsing recursive
      # multiparts.
      def initialize(input, boundary)
        super(input)
        escaped = Regexp.escape(boundary)
        @delimiter_re = /(?:\G|\n)--#{escaped}(--)?\s*?(\n|\z)/
        @might_be_delimiter_re = might_be_delimiter_re(boundary)
        @caryover = nil
        @chunks = []
        @eof = false
        @delimiter = nil
        @delimiter_is_last = false
        @in_epilogue = false
        @in_preamble = true
      end

      # Returns the next chunk of data from the input stream as a
      # string.  The chunk_size is passed down to the read method of
      # this object's input stream to suggest a size to it, but don't
      # depend on the returned data being of any particular size.
      #
      # If this method returns nil, you must call next_part to begin
      # reading the next MIME part in the data stream.
      def read_chunk(chunk_size)
        chunk = read_chunk_low(chunk_size)
        if chunk
          if @in_epilogue
            while more = read_chunk_low(chunk_size)
              chunk << more
            end
          end
        end
        chunk
      end

      def read_chunk_low(chunk_size)

        if @pushback
          return standard_read_chunk(chunk_size)
        end

        input_gave_nil = false
        loop {
          return nil if @eof || @delimiter

          unless @chunks.empty?
            chunk, @delimiter, @delimiter_is_last = @chunks.shift
            return chunk
          end

          chunk = standard_read_chunk(chunk_size)

          if chunk.nil?
            input_gave_nil = true
          end
          if @caryover
            if chunk
              @caryover << chunk
            end
            chunk = @caryover
            @caryover = nil
          end

          if chunk.nil?
            @eof = true
            return nil
          elsif @in_epilogue
            return chunk
          end

          start = 0
          found_last_delimiter = false

          while !found_last_delimiter and
              (start < chunk.length) and
              (found = chunk.index(@delimiter_re, start))

            if $~[2] == '' and !input_gave_nil
              break
            end

            delimiter = $~[0]

            # check if delimiter had the trailing --
            if $~.begin(1)
              found_last_delimiter = true
            end

            temp = if found == start
                     nil
                   else
                     chunk[start, found - start]
                   end

            @chunks << [ temp, delimiter, found_last_delimiter ]

            start = $~.end(0)
          end

          chunk = chunk[start..-1] if start > 0

          # If something that looks like a delimiter exists at the end
          # of this chunk, refrain from returning it.
          unless found_last_delimiter or input_gave_nil
            start = chunk.rindex(/\n/) || 0
            if chunk.index(@might_be_delimiter_re, start)
              @caryover = chunk[start..-1]
              chunk[start..-1] = ''
              chunk = nil if chunk.length == 0
            end
          end

          unless chunk.nil?
            @chunks << [ chunk, nil, false ]
          end
          chunk, @delimiter, @delimiter_is_last = @chunks.shift

          if chunk
            return chunk
          end
        }
      end

      # Start reading the next part.  Returns true if there is a next
      # part to read, or false if we have reached the end of the file.
      def next_part
        if @eof
          false
        else
          if @delimiter
            @delimiter = nil
            @in_preamble = false
            @in_epilogue = @delimiter_is_last
          end
          true
        end
      end

      # Call this to determine if #read is currently returning strings
      # from the preamble portion of a mime multipart.
      def preamble?
        @in_preamble
      end

      # Call this to determine if #read is currently returning strings
      # from the epilogue portion of a mime multipart.
      def epilogue?
        @in_epilogue
      end

      # Call this to retrieve the delimiter string that terminated the
      # part just read.  This is cleared by #next_part.
      def delimiter
        @delimiter
      end

      private

      def might_be_delimiter_re(boundary)
        s = PushbackReader.maybe_contains_re("--" + boundary)
        Regexp.new('(?:\A|\n)(?:' + s + '|\z)')
      end

    end
  end
end
