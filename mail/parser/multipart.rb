#!/usr/bin/env ruby
#--
#   Copyright (C) 2002 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

module Mail
  class Parser

    class Error < StandardError
    end

    class PushbackReader
      def initialize(input)
        @input = input
        @pushback = nil
      end

      def read(size = 16384)
        if @pushback
          temp = @pushback
          @pushback = nil
          temp
        else
          @input.read(size)
        end
      end

      def pushback(string)
        raise Error, 'You have already pushed a string back.' if @pushback
        @pushback = string
      end
    end

    # A simple interface to facilitate parsing a multipart message.
    class MultipartReader < PushbackReader

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
        @boundary = boundary
        escaped = Regexp.escape(boundary)
        @boundary_re = /(\A|\n)--#{escaped}(--)?.*?(\n)?/
        @first_chunk = true
        @might_be_boundary_re = might_be_boundary_re(@boundary)
        @caryover = nil
        @chunks = []
        @eof = false
        @found_boundary = false
        @found_last_boundary = false
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
      def read(chunk_size = 16384)

        if @pushback
          temp = @pushback
          @pushback = nil
          return temp
        end

        # The basic algorithm:
        #
        # If we've reached the end of the file or if the last chunk
        # returned was the last of its part, return nil.
        #
        # If we have any saved chunks from previous calls, return the
        # first one.
        #
        # Otherwise read in a chunk sized piece of data and prepend
        # any previous caryover data from the previous chunk.
        #
        # If we couldn't read any more data, return nil.
        #
        # If we're reading data from the epilogue, return the chunk
        # unprocessed.
        #
        # Otherwise, look for boundary markers in the chunk as
        # follows:
        #
        #  - Look for a complete boundary.  If found, append the stuff
        #    before the boundary to the chunks array.  If we found the
        #    end boundary, break out of the loop, otherwise repeat.
        #
        #  - Take the remainder of the chunk, if any, and create a
        #    chunk from it as follows:
        #
        #    -- Unless we found the end boundary or our last read from
        #       our data source returned nil, check the end of the
        #       chunk for what might be a boundary marker.  Do this by
        #       searching backwards from the end of the chunk for "\n"
        #       and searching forward for something that might be a
        #       boundary.  If found, chop off the whole portion.  Then
        #       make sure we have at least 2 characters after our
        #       potential boundary so any trailing '--' is guaranteed
        #       to be present.  Then save it as caryover data, to be
        #       prepended to the next read.
        #
        #    -- Append whatever remains, even if it is a string of
        #       length zero to the chunks array.
        #
        #  - Now return the first element of the chunks array.
        #
        # If we are reading the epilogue, skip all the boundary logic
        # above and just return the chunk without further processing.
        #
        loop {
          return nil if @eof || @found_boundary

          unless @chunks.empty?
            chunk, @found_boundary, @found_last_boundary = @chunks.shift
            raise if chunk.nil? && !@found_boundary
            return chunk
          end

          chunk = @input.read(chunk_size)
          input_gave_nil = chunk.nil?
          if @caryover
            if chunk
              chunk[0, 0] = @caryover
            else
              chunk = @caryover
            end
            @caryover = nil
          end

          if chunk.nil?
            @eof = true
            return nil
          elsif @in_epilogue
            return chunk
          end

          start = 0
          found_last_boundary = false

          while found = chunk.index(@boundary_re, start)
            # Insist on leading newline unless this is the very first
            # chunk
            if $~.end(1) == 0 && !@first_chunk
              start = $~.end(0)
              redo
            end
            # Make sure we've got the trailing newline
            break unless $~.begin(3) || input_gave_nil
            # check if boundary had the trailing --
            if $~.begin(2)
              found_last_boundary = true
            end
            temp = if found == start
                     nil
                   else
                     chunk[start, found - start]
                   end
            @chunks << [ temp, true, found_last_boundary ]
            start = $~.end(0)
            break if found_last_boundary
          end
          chunk[0, start] = ''
          chunk = nil if chunk.length == 0
          unless chunk.nil? || found_last_boundary || input_gave_nil
            start = chunk.rindex(/\n/)
            if !start && @first_chunk
              start = 0
            end
            if start
              while start > 0 && chunk[start - 1] == ?\n
                start -= 1
              end
              if chunk.index(@might_be_boundary_re, start)
                match_end = $~.end(0)
                @caryover = chunk[start..-1]
                chunk[start..-1] = ''
                while (@caryover.length - match_end) < 2
                  temp = @input.read(chunk_size)
                  break unless temp
                  @caryover << temp
                end
              end
            end
          end
          @chunks << [ chunk, false, false ] unless chunk.nil?
          raise if @chunks.length == 0
          chunk, @found_boundary, @found_last_boundary = @chunks.shift
          if chunk.nil? || chunk.length > 0
            @first_chunk = false
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
          if @found_boundary
            @in_preamble = false
            @in_epilogue = @found_last_boundary
            @found_boundary = false
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

      private

      def might_be_boundary_re(boundary)
        left = '(?:\A|\n)'
        right = ''
        ('--' + boundary).each_byte { |ch|
          left << '(?:'
          left << Regexp.quote(ch.chr)
          right[right.length, 0] = '|\z)'
        }
        Regexp.new(left + right)
      end

    end
  end
end


if $0 == __FILE__

  def print_read_result(depth, line, parser)
    puts "#{depth} read -> " + line.inspect + " [preamble #{parser.preamble?}, epilogue #{parser.epilogue?}]"
  end

  def parse(parser, depth, chunk_size)
    while true
      line = parser.read(chunk_size)
      print_read_result(depth, line, parser)
      if line.nil?
        res = parser.next_part
        puts "#{depth} next_part -> " + res.inspect
        unless res
          puts "#{depth} returning"
          break
        end
      end
    end
  end

  File.open("../../tests/data/parser.multipart.epilogue") { |f|
    p = Mail::Parser::MultipartReader.new(f, 'X')
    parse(p, 0, 1)
  }
end
