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

    # A simple file like interface to facilitate parsing a multipart
    # message.
    class Multipart

      class Error < StandardError
      end

      # Initialize this parser.  +input+ is an object supporting a
      # +gets+ method that returns nil when this part is completed.
      # This class is a suitable input source when parsing recursive
      # multiparts.  +boundary+ is the string boundary that separates
      # the parts.
      def initialize(input, boundary)
        @input = input

        @boundary = boundary
        @eof = false
        @part_end = false
        @final_part = false

        @in_epilogue = false
        @in_preamble = true
      end

      # Return the next line of this part.  Returns nil when a part
      # boundary has been hit.  At that time, call next_part to start
      # reading the next part.
      def gets
        return nil if @eof || @part_end
        line = @input.gets
        if line.nil?
          @eof = true
        elsif ! @in_epilogue && line[0, 2] == '--'
          if line[2, @boundary.length] == @boundary
            @part_end = true
            @final_part = line[2 + @boundary.length, 2] == '--'
            line = nil
          end
        end
        line
      end

      # Start reading the next part.  Returns true if there is a next
      # part to read, or false otherwise.
      def next_part
        if @eof
          false
        else
          if @part_end
            @in_preamble = false
            @in_epilogue = @final_part
            @part_end = false
          end
          true
        end
      end

      # Call this to determine if gets is currently returning strings
      # from the preamble portion of a mime multipart.
      def preamble?
        @in_preamble
      end

      # Call this to determine if gets is currently returning strings
      # from the epilogue portion of a mime multipart.
      def epilogue?
        @in_epilogue
      end

    end
  end
end



if $0 == __FILE__

  def parse(parser, depth)
    while true
      line = parser.gets
      puts "#{depth} gets -> " + line.inspect + " [preamble #{parser.in_preamble}, epilogue #{parser.in_epilogue}]"
      if line =~ /push_boundary (\w+)/
        puts "#{depth} recurse!"
        parse(Mail::Parser::Multipart.new(parser, $1), depth + 1)
      end
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

  File.open("/home/matt/rubymail/tests/data/parser.multipart.simple") { |f|
    p = Mail::Parser::Multipart.new(f, 'X')
    parse(p, 0)
  }
end
