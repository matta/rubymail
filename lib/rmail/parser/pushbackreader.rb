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
# Implements the RMail::Parser::PushbackReader class.

module RMail
  class Parser

    class Error < StandardError; end

    # A utility class for reading from an input source in an efficient
    # chunked manner.
    #
    # The idea is to read data in descent sized chunks (the default is
    # 16k), but provide a way to "push back" some of the chunk if we
    # read too much.
    #
    # This class is useful only as a base class for other readers --
    # e.g. a reader that parses MIME multipart documents, or a reader
    # that understands one or more mailbox formats.
    #
    # The typical RubyMail user will have no interest in this class.
    # ;-)
    class PushbackReader        # :nodoc:

      # Create a PushbackReader and have it read from a given input
      # source.
      #
      # The input source must either be a String or respond to the
      # "read" method in the same way as an IO object.
      def initialize(input)
        unless defined? input.read(1)
          unless input.is_a?(String)
            raise ArgumentError, "input object not IO or String"
          end
          @pushback = input
          @input = nil
        else
          @pushback = nil
          @input = input
        end
        @chunk_size = 16384
      end

      # Read a chunk of input.  The "size" argument is just a
      # suggestion, and more or fewer bytes may be returned.  If
      # "size" is nil, then return the entire rest of the input
      # stream.
      def read(size = @chunk_size)
        case size
        when nil
          chunk = nil
          while temp = read(@chunk_size)
            if chunk
              chunk << temp
            else
              chunk = temp
            end
          end
          chunk
        when Fixnum
          read_chunk(size)
        else
          raise ArgumentError,
            "Read size (#{size.inspect}) must be a Fixnum or nil."
        end
      end

      # Read a chunk of a given size.  Unlike #read, #read_chunk must
      # be passed a chunk size, and cannot be passed nil.
      #
      # This is the function that should be re-defined in subclasses
      # for specialized behavior.
      def read_chunk(size)
        standard_read_chunk(size)
      end

      # The standard implementation of read_chunk.  This can be
      # convenient to call from derived classes when super() isn't
      # easy to use.
      def standard_read_chunk(size)
        unless size.is_a?(Fixnum) && size > 0
          raise ArgumentError,
            "Read size (#{size.inspect}) must be greater than 0."
        end
        if @pushback
          chunk = @pushback
          @pushback = nil
        elsif ! @input.nil?
          chunk = @input.read(size)
        end
        return chunk
      end

      # Push a string back.  This will be the next chunk of data
      # returned by #read.
      #
      # Because it has not been needed and would compromise
      # efficiency, only one chunk of data can be pushed back between
      # successive calls to #read.
      def pushback(string)
        raise RMail::Parser::Error,
          'You have already pushed a string back.' if @pushback
        @pushback = string
      end

      # Retrieve the chunk size of this reader.
      attr_reader :chunk_size

      # Set the chunk size of this reader in bytes.  This is useful
      # mainly for testing, though perhaps some operations could be
      # optimized by tweaking this value.  The chunk size must be a
      # Fixnum greater than 0.
      def chunk_size=(size)
        unless size.is_a?(Fixnum)
          raise ArgumentError, "chunk size must be a Fixnum"
        end
        unless size >= 1
          raise ArgumentError, "invalid size #{size.inspect} given"
        end
        @chunk_size = size
      end

      # Returns true if the next call to read_chunk will return nil.
      def eof
        @pushback.nil? and (@input.nil? or @input.eof)
      end

      # Creates a regexp that'll match the given boundary string in
      # its entirely anywhere in a string, or any partial prefix of
      # the boundary string so long as the match is anchored at the
      # end of the string.  This is useful for various subclasses of
      # PushbackReader that need to know if a given input chunk might
      # contain (or contain just the beginning of) an interesting
      # string.
      def self.maybe_contains_re(boundary)
        left = Regexp.quote(boundary[0,1])
        right = ''
        boundary[1..-1].each_byte { |ch|
          left << '(?:'
          left << Regexp.quote(ch.chr)
          right << '|\z)'
        }
        left + right
      end

    end

  end
end
