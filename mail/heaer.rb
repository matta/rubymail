=begin
   Copyright (C) 2001 Matt Armstrong.  All rights reserved.

   Permission is granted for use, copying, modification, distribution,
   and distribution of modified versions of this work as long as the
   above copyright notice is included.
=end

module Mail

  # A class that supports the reading, writing and manipulation of
  # RFC2822 mail headers.
  #
  # FIXME: missing a delete method.  Doh!

  class Header
    include Enumerable

    # fixme, document methadology for this (RFC2822)
    FIELD_NAME = '[^\x00-\x1f\x7f-\xff :]+:';
    EXTRACT_FIELD_NAME_RE = /\A(#{FIELD_NAME}|From )/o

    # Creates a new header object.  If +input+ is not nil, immediately
    # calls #read to process the headers found in +input+.

    def initialize(input = nil)
      clear()
      read(input) unless input.nil?
    end

    # Reads from +input+ up to and including the blank line that
    # separates the message headers from the message body.  Each
    # parseable header line is appended to this object.
    #
    # FIXME: this should not use <tt>each_line</tt> but rather use
    # <tt>input.gets</tt>.
    #
    # FIXME: If there is a "put back last line" API available on
    # +input+, then the line that causes parsing to stop should be
    # pushed back.
    #
    # FIXME: As soon as a malformed header is found, it should
    # terminate parsing.  This allows the caller to determine what
    # should happen next.

    def read(input)
      line = nil
      field_name = nil
      input.each_line {|ln|
	if ln && line && ln =~ /\A[ \t]+/
	  line += ln
	  next
	end

	if line
	  field_name, line = format_line(field_name, line)
	  insert(field_name, line) if line
	end

	case ln
	when EXTRACT_FIELD_NAME_RE
	  field_name = $1
	  line = ln
	when /^$/
	  break
	else
	  field_name = nil
	  line = nil
	end
      }
    end

    # Erase all headers in this object.

    def clear()
      @names = []
      @lines = []
    end

    # Return the number of fields in this object
    def length
      @names.length
    end

    # Synonym for #length.
    def size
      @names.length
    end

    # Iterate over each header.

    def each() # yields: field_name, line
      unless @names.nil?
	@names.each_index { |i|
	  yield(@names[i], @lines[i])
	}
      end
    end

    # Return the first matching header of a given field name.  The
    # string returned is the entire header line.  If passed a Fixnum,
    # returns the header indexed by the number.

    def [](field_name)
      if field_name.kind_of? Fixnum
	@lines[field_name]
      else
	unless field_name.kind_of? String
	  raise TypeError, "wanted type String, got type #{field_name.class}"
	end
	field_name = field_name_format(field_name)
	result = detect { |t, v| if t == field_name then true else nil end }
	if result.nil? then nil else result[1] end
      end
    end

    # Return the first matching header of a given name.  This will not
    # include the header field name.
    #
    # This method accepts all argument types that #[] does.
    def get(field_name)
      header = self[field_name]
      unless header.nil?
	Mail::Header.strip_field_name(header)
      else
	nil
      end
    end

    # Match +regexp+ against all fields in the header with a field
    # name of <tt>field_name</tt>.  If <tt>field_name</tt> is nil, all
    # fields are tested.  Returns a new Mail::Header holding all
    # matching headers.
    #
    # See also: #match?
    def match(field_name, regexp)
      massage_match_args(field_name, regexp) { |field_name, regexp|
	header = Mail::Header.new
	found = each { |t, f|
	  if (field_name.nil? || t == field_name) && f =~ regexp
	    header.insert(t, f)
	  end
	}
	header
      }
    end

    # Match +regexp+ against all fields in the header with a field
    # name of <tt>field_name</tt>.  If <tt>field_name</tt> is nil, all
    # fields are tested.  Returns true if there is a match, false
    # otherwise.
    #
    # See also: #match
    def match?(field_name, regexp)
      massage_match_args(field_name, regexp) { |field_name, regexp|
	match = detect {|t, f|
	  (field_name.nil? || t == field_name) && f =~ regexp
	}
	! match.nil?
      }
    end

    class << self

      # Returns the +header+ string with any header field name
      # removed.  E.g.
      #
      #     Mail::Header.strip_field_name("From: bob@example.net")
      #     => " bob@example.net"
      def strip_field_name(header)
	unless header =~ EXTRACT_FIELD_NAME_RE
	  header
	else
	  $'.sub(/^\s*/, '')
	end
      end
    end

    # Add a new header.  If <tt>field_name</tt> is not nil, then it
    # specifies the field name to use, otherwise it is extracted from
    # line.  When +index+ is -1 (the default if not specified) the
    # line is appended to the header, otherwise it is inserted at the
    # specified index.  E.g. an +index+ of 0 will prepend the header
    # line.

    def add(field_name, line, index = -1)
      if field_name.nil?
	if line !~ EXTRACT_FIELD_NAME_RE
	  raise ArgumentException, "can not extract header from line"
	end
	field_name = $1
      else
	line = field_name_format(field_name) + ": " + line
      end
      if line =~ /\n\S/
	raise ArgumentError, "line has no space after embedded newline"
      end
      field_name, line = format_line(field_name, line)
      insert(field_name, line, index)
    end

    # The string representation of the header
    def to_s()
      @lines.join
    end

    protected

    def insert(field_name, line, index = -1)
      if index < 0
	@lines.push(line)
	@names.push(field_name)
      else
	index = @lines.length if index > @lines.length
	@lines[index, 0] = line
	@names[index, 0] = field_name
      end
    end

    private
    
    def format_line(field_name, line)
      return field_name_format(field_name), line_format(line)
    end

    def line_format(line)
      if line[-1] != ?\n
	line << ?\n
      end
      line
    end

    def field_name_format(field_name)
      field_name.downcase.sub(/\s*:.*/, '')
    end

    def massage_match_args(field_name, regexp)
      unless field_name.nil? || field_name.kind_of?(String)
	raise ArgumentError, "must be" +
	  " a string or nil, got #{field_name.inspect}"
      end
      unless regexp.kind_of?(Regexp)
	raise ArgumentError, "regexp arg not of type Regexp" +
	  ", got #{regexp.inspect}."
      end
      field_name = field_name.downcase unless field_name.nil?
      yield(field_name, regexp)
    end

  end

end
