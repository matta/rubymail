#!/usr/bin/env ruby
#--
#   Copyright (c) 2004, 2005 Matt Armstrong.  All rights reserved.
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
# Implements the RMail::Superstring and RMail::Substring classes.

module RMail

  # The RMail::Substring class is a means of keeping track of a
  # particular substring within a RMail::Superstring.
  #
  # This class attempts to be a little bit like a String, but it does
  # not try very hard.  Instead, the to_s method is provided.
  #
  # The intent behind this class is to provide a way to have many
  # parsed substrings reference the same string storage, thereby
  # saving memory.  The RubyMail parser uses this to keep only a
  # single copy of the message data in memory, even with deeply nested
  # multipart messages, etc.
  #
  # You will see this class returned from the RMail::Message#body
  # method when the message is created with the RubyMail parser.
  class Substring
    include Enumerable
    include Comparable

    # Creating a RMail::Substring requires a +superstring+, and a
    # start index and byte length.
    def initialize(superstring, byte_index, byte_length)
      #
      # Various sanity checks on the argument.
      #
      if byte_index < 0
        raise ArgumentError, "illegal negative start #{byte_index}"
      end
      if byte_length < 0
        raise ArgumentError, "illegal negative length #{byte_length}"
      end
      if byte_index + byte_length > superstring.length
        raise ArgumentError, "ending position #{byte_index + byte_length} " +
          "is past the end of the superstring (length #{superstring.length})"
      end

      @superstring = superstring
      @start = byte_index
      @length = byte_length
    end

    # A RMail::Substring can't really be treated as a String
    # object.  This method returns a copy of the string data.
    def to_s
      return @superstring.slice(@start, @length)
    end

    # Return a copy of the string data.
    def to_str
      to_s
    end

    # For sanity while debugging, this object just prints the string
    # and not the parent Superstring, etc.
    def inspect
      to_s.inspect
    end

#     def inspect
#       "#<%s:%s @range=%s @superstring=#<%s:%d>>" % [
#         self.class, __id__, @range.inspect,
#         @superstring.class, @superstring.__id__ ]
#     end

    # Return the length of the Substring
    def length
      @length
    end

    # Compare this Substring against another.  They compare equal if
    # they have the same string value.  For convenience, you can pass
    # anything that responds to to_str as the +other+ string.
    def ==(other)
      to_str == other.to_str
    end

    # Index an individual character in the Substring.
    def [](arg)
      if arg < 0
        arg = @length + arg
        if arg < 0
          return nil
        end
      end
      if arg >= @length
        return nil
      end
      @superstring[arg + @start]
    end

    # For convenience, this method behaves like String#each.
    def each(&proc)
      each_line(&proc)
    end

    # For convenience, this method behaves like String#each_line.
    def each_line(&proc)
      to_str.each_line(&proc)
    end

  end

  # The RMail::Superstring class is a parent string which multiple
  # RMail::Substring objects reference.  You will not need to use
  # one of these when using RubyMail in the typical way.
  class Superstring

    def initialize
      @store = ''
      @protect_length = 0
    end

    # Append a string to the superstring.
    def <<(str)
      @store << str
    end

    # Create a RMail::Substring given a start offset and a length.
    def substring(start, length)
      Substring.new(self, start, length)
    end

    # Don't allow truncation to shorten the string more than length.
    def protect(length)
      if length > self.length
        raise ArgumentError, "length #{length.inspect} greater than " +
          "maximum of #{self.length}"
      end
      @protect_length = [length, @protect_length].max
    end

    # Return a copy of the stored data as a new string, given a
    # particular range.
    def slice(start, length)
      @store.slice(start, length)
    end

    # Freeze the entire object.
    def freeze
      @protect_length = length
      @store.freeze
      super
    end

#    def inspect
#      "#<#{self.class}:#{self.__id__} @store=#{@store.inspect}>"
#    end

    # Return the length of the string.
    def length
      @store.length
    end

    # Truncate at a given length.
    def truncate(length)
      if length < @protect_length
        raise ArgumentError, "can not truncate shorter than " +
          "#{@protect_length}, #{length} attempted."
      else
        @store[length..-1] = ''
      end
    end

    # Index a character of the string.
    def [](arg)
      @store[arg]
    end

  end

end
