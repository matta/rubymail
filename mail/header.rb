#!/usr/bin/env ruby
#
#   Copyright (c) 2001 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

module Mail
  class Header
    include Enumerable

    # fixme, document methadology for this (RFC2822)
    FIELD_NAME = '[^\x00-\x1f\x7f-\xff :]+:';
    EXTRACT_TAG_RE = /\A(#{FIELD_NAME}|From )/o
    
    # Initializes the object.  Consumes input up to and including the blank
    # line in input separating the header from the message body.

    def initialize(input = nil)
      clear()
      read(input) unless input.nil?
    end

    def read(input)
      line = nil
      tag = nil
      input.each_line {|ln|
	if ln && line && ln =~ /\A[ \t]+/
	  line += ln
	  next
	end

	if line
	  tag, line = format_line(tag, line)
	  insert(tag, line, -1) if line
	end

	case ln
	when EXTRACT_TAG_RE
	  tag = $1
	  line = ln
	when /^$/
	  break
	else
	  tag = nil
	  line = nil
	end
      }
    end

    def clear()
      @names = []
      @lines = []
    end

    # Iterate over each field.  Two vars are set in the result:
    # |tag, line|.
    def each()
      unless @names.nil?
	@names.each_index { |i|
	  yield(@names[i], @lines[i])
	}
      end
    end

    # Return the first matching header of a given name.  This will
    # include the header tag.  If passed a Fixnum, returns the header
    # indexed by the number.
    def [](tag)
      if tag.kind_of? Fixnum
	@lines[tag]
      else
	unless tag.kind_of? String
	  raise TypeError, "wanted type String, got type #{tag.class}"
	end
	tag = tag_format(tag)
	result = detect { |t, v| if t == tag then true else nil end }
	if result.nil? then nil else result[1] end
      end
    end

    # Return the first matching header of a given name.  This will not
    # include the header tag
    def get(tag)
      header = self[tag]
      unless header.nil?
	Mail::Header.strip_tag(header)
      else
	nil
      end
    end

    # Strip a tag from a header line
    class << self
      def strip_tag(header)
	unless header =~ EXTRACT_TAG_RE
	  header
	else
	  $'.sub(/^\s*/, '')
	end
      end
    end

    # Add a new line to the header.  If 'tag' is not nil, then it specifies
    # the tag to use, otherwise it is extracted from line.  When index is -1
    # (the default if not specified) the line is appended to the header,
    # otherwise it is inserted at the specified index.  E.g. an index of 0
    # will prepend the line to the header.
    def add(tag, line, index = -1)
      if tag.nil?
	if line !~ EXTRACT_TAG_RE
	  raise ArgumentException, "can not extract header from line"
	end
	tag = $1
      else
	line = tag_format(tag) + ": " + line
      end
      if line =~ /\n\S/
	raise ArgumentError, "line has no space after embedded newline"
      end
      tag, line = format_line(tag, line)
      insert(tag, line, index)
    end

    # The string representation of the header
    def to_s()
      @lines.join
    end

    private

    def insert(tag, line, index)
      if index < 0
	@lines.push(line)
	@names.push(tag)
      else
	index = @lines.length if index > @lines.length
	@lines[index, 0] = line
	@names[index, 0] = tag
      end
    end

    def format_line(tag, line)
      return tag_format(tag), line_format(line)
    end

    def line_format(line)
      if line[-1] != ?\n
	line << ?\n
      end
      line
    end

    def tag_format(tag)
      tag.downcase.sub(/\s*:.*/, '')
    end
    
  end

end
