#!/usr/bin/env ruby
#--
#   Copyright (C) 2002 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

module RMail
  class Parser

    require 'rmail/parser/pushbackreader'

    # A simple interface to facilitate parsing a multipart message.
    #
    # The typical RubyMail user will have no use for this class.
    # Although it is an example of how to use a PushbackReader, the
    # typical RubyMail user will never use a PushbackReader either.
    # ;-)
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
        @boundary_re = /\n--#{escaped}(--)?.*?\n/
        @might_be_boundary_re = might_be_boundary_re(@boundary)
        @caryover = nil
        @chunks = []
        @eof = false
        @found_boundary = false
        @found_last_boundary = false
        @in_epilogue = false
        @in_preamble = true
        @have_read_first_byte = false
      end

      # Returns the next chunk of data from the input stream as a
      # string.  The chunk_size is passed down to the read method of
      # this object's input stream to suggest a size to it, but don't
      # depend on the returned data being of any particular size.
      #
      # If this method returns nil, you must call next_part to begin
      # reading the next MIME part in the data stream.
      def read(chunk_size = @chunk_size)

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
        input_gave_nil = false
        loop {
          return nil if @eof || @found_boundary

          puts "top of loop, @chunks now #{@chunks.inspect}" if $DEBUG

          unless @chunks.empty?
            chunk, @found_boundary, @found_last_boundary = @chunks.shift
            raise if chunk.nil? && !@found_boundary
            return chunk
          end

          chunk = @input.read(chunk_size)

          if !@have_read_first_byte && chunk && chunk.length > 0
            # If the first byte we read is '-' we might be looking at
            # the first boundary.  Prepend the newline so the regexps
            # will find it.  We can't depend on chunk being any longer
            # than one byte here.
            if chunk[0] == ?-
              chunk[0,0] = "\n"
              puts "prepend newline to first chunk" if $DEBUG
            end
            @have_read_first_byte = true
          end

          puts "chunk read #{chunk.inspect}" if $DEBUG
          if chunk.nil?
            input_gave_nil = true
          end
          if @caryover
            if chunk
              chunk[0, 0] = @caryover
            else
              chunk = @caryover
            end
            @caryover = nil
          end
          puts "chunk w/carryover #{chunk.inspect}" if $DEBUG

          if chunk && input_gave_nil
            # If input didn't end with a newline, add one so our
            # regexps work.
            if chunk[-1] != ?\n
              chunk << ?\n
            end
          end

          if chunk.nil?
            puts "eof #{chunk.inspect}" if $DEBUG
            @eof = true
            return nil
          elsif @in_epilogue
            puts "in epilogue, returning chunk #{chunk.inspect}" if $DEBUG
            return chunk
          end

          start = 0
          found_last_boundary = false

          while start < chunk.length &&
              found = chunk.index(@boundary_re, start)

            puts "found boundary in #{chunk.inspect} at #{found.inspect} with start at #{start.inspect}" if
              $DEBUG
            # check if boundary had the trailing --
            if $~.begin(1)
              puts "we found the last boundary" if $DEBUG
              found_last_boundary = true
            end
            temp = if found == start
                     nil
                   else
                     chunk[start, found - start]
                   end
            puts "found boundary, saving chunk #{temp.inspect} off" if $DEBUG
            @chunks << [ temp, true, found_last_boundary ]
            puts "chunks now #{@chunks.inspect}" if $DEBUG
            # We start searching again beginning with the newline at
            # the end of this line.
            start = $~.end(0) - 1
            puts "start now #{start.inspect} into #{chunk.inspect}" if $DEBUG
            break if found_last_boundary
          end
          chunk[0, start] = ''
          chunk = nil if chunk.length == 0
          puts "after boundary splitting chunk is #{chunk.inspect}" if $DEBUG

          # If something that looks like a boundary exists at the end
          # of this chunk, refrain from returning it.
          unless chunk.nil? || found_last_boundary || input_gave_nil
            start = chunk.rindex(/\n/)
            if !start
              start = 0
            end
            puts "look for boundaries starting at #{start.inspect}" if
              $DEBUG
            if start
              while start > 0 && chunk[start - 1] == ?\n
                start -= 1
              end
              puts "adjusted start is #{start.inspect}" if $DEBUG
              if chunk.index(@might_be_boundary_re, start)
                puts "found potential boundary" if $DEBUG
                match_end = $~.end(0)
                @caryover = chunk[start..-1]
                chunk[start..-1] = ''
                chunk = nil if chunk.length == 0
                puts "carryover now #{@caryover.inspect}" if $DEBUG
                puts "chunk now #{chunk.inspect}" if $DEBUG
                while (@caryover.length - match_end) < 2
                  temp = @input.read(chunk_size)
                  break unless temp
                  @caryover << temp
                  puts "padded caryover now #{@caryover.inspect}" if $DEBUG
                end
              end
            end
          end

          @chunks << [ chunk, false, false ] unless chunk.nil?

          puts "end of loop, @chunks #{@chunks.inspect}" if $DEBUG

          chunk, @found_boundary, @found_last_boundary = @chunks.shift

          if chunk
            puts "returning chunk #{chunk.inspect}" if $DEBUG
            puts "  preamble #{preamble?.inspect}" if $DEBUG
            puts "  epilogue #{epilogue?.inspect}" if $DEBUG
            return chunk
          end
        }
      end

      # Start reading the next part.  Returns true if there is a next
      # part to read, or false if we have reached the end of the file.
      def next_part
        puts "- next part" if $DEBUG
        if @eof
          puts "- sorry dude, we're at EOF" if $DEBUG
          false
        else
          if @found_boundary
            @in_preamble = false
            @in_epilogue = @found_last_boundary
            @found_boundary = false
            puts "- preamble #{@in_preamble.inspect} epilogue #{@in_epilogue.inspect}" if $DEBUG
          end
          puts "- go!" if $DEBUG
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
        PushbackReader.maybe_contains_re("\n--" + boundary)
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

  File.open("../../tests/data/transparency/message.2") { |f|
    p = RMail::Parser::MultipartReader.
      new(f, '----=_NextPart_000_007F_01BDF6C7.FABAC1B0')
    parse(p, 0, 1)
  }
end
