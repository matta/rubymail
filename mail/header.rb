=begin
   Copyright (C) 2001, 2002 Matt Armstrong.  All rights reserved.

   Permission is granted for use, copying, modification, distribution,
   and distribution of modified versions of this work as long as the
   above copyright notice is included.
=end

require 'mail/utils'

module Mail

  # A class that supports the reading, writing and manipulation of
  # RFC2822 mail headers.

  # =Overview
  #
  # The Mail::Header class supports the creation and manipulation of
  # RFC2822 mail headers.
  #
  # A mail header is a little bit like a Hash.  The fields are keyed
  # by a string field name.  It is also a little bit like an Array,
  # since the fields are in a specific order.  This class provides
  # many of the methods of both the Hash and Array class.  It also
  # includes the Enumerable class.
  #
  # =Terminology
  #
  # header:: The entire header.  Each Mail::Header object holds one
  #          header.
  #
  # field:: An element of the header.  Fields have a name and a value.
  #         For example, the field "Subject: Hi Mom!" has a name of
  #         "Subject" and a value of "Hi Mom!"
  #
  # name:: A name of a field.  For example: "Subject" or "From".
  #
  # value:: The value of a field.
  #
  # =Conventions
  #
  # The header's fields are stored in a particular order.  Methods
  # such as each process the headers in this order.
  #
  # When field names or values are added to the object they are
  # frozen.  This helps prevent accidental modification to what is
  # stored in the object.
  class Header
    include Enumerable

    FIELD = Struct::new(:name, :value)

    # Creates a new empty header object.
    def initialize()
      clear()
    end

    # Return the value of the first matching header of a given field
    # name, or nil if none found.  If passed a Fixnum, returns the
    # header indexed by the number.
    def [](name_or_index)
      if name_or_index.kind_of? Fixnum
        temp = @fields[name_or_index]
        temp = temp.value unless temp.nil?
      else
        name = field_name_format(name_or_index.to_s)
        result = detect { |n, v|
          if field_name_format(n) == name then true else false end
        }
        if result.nil? then nil else result[1] end
      end
    end

    # Creates a shallow copy of this header object.  A new
    # Mail::Header is created and the instance data is copied over.
    # However, the new object will still reference the same strings
    # held in the original object, so in place modifications of the
    # strings will affect both objects.
    def dup
      #h = Mail::Header.new
      h = super
      h.fields = @fields.dup
      h.mbox_from = @mbox_from
      h
    end

    # Creates a deep copy of this header object, including any
    # singleton methods and strings.  The returned object will be a
    # complete and unrelated duplicate of the original.
    def clone
      h = super
      h.fields = Marshal::load(Marshal::dump(@fields))
      h.mbox_from = Marshal::load(Marshal::dump(@mbox_from))
      h
    end

    # Delete all fields in this object.  Returns self.
    def clear()
      @fields = []
      @mbox_from = nil
      self
    end

    # Replaces the contents of this header with that of another
    # header.  Returns self.
    def replace(other)
      unless other.kind_of?(Mail::Header)
        raise TypeError, "#{other.type.to_s} is not of type Mail::Header"
      end
      temp = other.dup
      @fields = temp.fields
      @mbox_from = temp.mbox_from
      self
    end

    # Return the number of fields in this object
    def length
      @fields.length
    end
    alias size length

    # Return the value of the first matching field of a given name
    # name.  If there is no such field, the value returned by the
    # block is returned.  If no block is passed, the value of
    # +default_value+ is returned.  If no +default_value+ is
    # specified, an IndexError exception is raised.
    def fetch(name, *rest)
      if rest.length > 1
        raise ArgumentError, "wrong # of arguments(#{rest.length + 1} for 2)"
      end
      result = self[name]
      if result.nil?
        if block_given?
          yield name
        elsif rest.length == 1
          rest[0]
        else
          raise IndexError, 'name not found'
        end
      else
        result
      end
    end

    # Returns the values of every field named +name+.  If there are no
    # such fields, the value returned by the block is returned.  If no
    # block is passed, the value of +default_value+ is returned.  If
    # no +default_value+ is specified, an IndexError exception is
    # raised.
    def fetch_all name, *rest
      if rest.length > 1
        raise ArgumentError, "wrong # of arguments(#{rest.length + 1} for 2)"
      end
      result = select(name)
      if result.nil?
        if block_given?
          yield name
        elsif rest.length == 1
          rest[0]
        else
          raise IndexError, 'name not found'
        end
      else
        result.collect { |n, v|
          v
        }
      end
    end

    # Returns true if the message has a field named 'name'.
    def field?(name)
      ! self[name].nil?
    end
    alias member? field?
    alias include? field?
    alias has_key? field?
    alias key? field?

    # Deletes all fields with +name+.  Returns self.
    def delete(name)
      name = field_name_format(name.to_s)
      delete_if { |n, v|
        field_name_format(n) == name
      }
      self
    end

    # Deletes the field at the specified index and returns its value.
    def delete_at(index)
      @fields[index, 1] = nil
      self
    end

    # Deletes the field if the passed block returns true.  Returns
    # self.
    def delete_if # yields: name, value
      @fields.delete_if { |i|
        yield i.name, i.value
      }
      self
    end

    # Removes the first field from the header and returns it as a [
    # name, value ] array.
    def shift
      raise
    end

    # Removes the last field from the header and returns it as a
    # [ name, value ] array.
    def unshift
      raise
    end

    # Executes block once for each field in the
    # header, passing the key and value as parameters.
    #
    # Returns self.
    def each                    # yields: name, value
      @fields.each { |i|
        yield(i.name, i.value)
      }
    end
    alias each_pair each

    # Executes block once for each field in the header, passing the
    # field's name as a parameter.
    #
    # Returns self
    def each_name
      @fields.each { |i|
        yield(i.name)
      }
    end
    alias each_key each_name

    # Executes block once for each field in the header, passing the
    # field's value as a parameter.
    #
    # Returns self
    def each_value
      @fields.each { |i|
        yield(i.value)
      }
    end

    # Returns true if the header contains no fields
    def empty?
      @fields.empty?
    end

    # Returns an array of pairs [ name, value ] for all fields with
    # one of the names passed.
    def select(*names)
      result = []
      names.each { |name|
        name = field_name_format(name.to_s)
        result.concat(find_all { |n, v|
          field_name_format(n) == name
        })
      }
      result
    end

    # Returns an array consisting of the names of every field in this
    # header.
    def names
      collect { |n, v|
        n
      }
    end
    alias keys names

    # Add a new field with +name+ and +value+.  When +index+ is nil
    # (the default if not specified) the line is appended to the
    # header, otherwise it is inserted at the specified index.
    # E.g. an +index+ of 0 will prepend the header line.
    #
    # You can pass additional parameters for the header as a hash
    # table +params+.  Every key of the hash will be the name of the
    # parameter, and every key's value the parameter value.
    #
    # E.g.
    #
    #    header.add('Content-Type', 'multipart/mixed', nil,
    #               'boundary' => 'the boundary')
    #
    # will add this header
    #
    #    Content-Type: multipart/mixed; boundary="the boundary"
    #
    # Always returns self.
    def add(name, value, index = nil, params = nil)

      value = value.to_s
      if params
        value = value.dup
        sep = "; "
        params.each do |n, v|
          value << sep
          value << n.to_s
          value << '='
          v = v.to_s
          if v =~ /^\w+$/
            value << v
          else
            value << '"'
            value << v
            value << '"'
          end
        end
      end

      field = FIELD.new(field_name_strip(name.to_s).freeze,
                        value.freeze)
      index ||= @fields.length
      @fields[index, 0] = field
      self
    end

    # Append a new field with +name+ and +value+.  If you want control
    # of where the field is inserted, see #add.
    #
    # Returns +value+.
    def []=(name, value)
      add(name, value)
      value
    end

    # Returns true if the two objects have the same number of fields,
    # in the same order, with the same values.
    def ==(other)
      return other.kind_of?(self.type) &&
        @fields == other.fields &&
        @mbox_from == other.mbox_from
    end

    # Returns a new array holding one [ name, value ] array per field
    # in the header.
    def to_a
      @fields.collect { |field|
        [ field.name, field.value ]
      }
    end

    # Converts the header to a string, including any mbox from line.
    # Equivalent to header.to_string(true).
    def to_s
      to_string(true)
    end

    # Converts the header to a string.  If +mbox_from+ is true, then
    # the mbox from line is also included.
    def to_string(mbox_from = false)
      s = ""
      if mbox_from && ! @mbox_from.nil?
        s << @mbox_from
        s << "\n" unless @mbox_from[-1] == ?\n
      end
      each { |n, v|
        s << n
        s << ': '
        s << v
        s << "\n" unless v[-1] == ?\n
      }
      s
    end

    # Match +regexp+ against all field values with a field name of
    # +name+.  If +name+ is nil, all fields are tested.  If +name+ is
    # a Regexp, the field names are matched against the regexp.
    # Returns true if there is a match, false otherwise.
    #
    # Returns a new Mail::Header holding all matching headers.
    #
    # See also: #match?
    def match(name, regexp)
      massage_match_args(name, regexp) { |name, regexp|
        header = Mail::Header.new
        found = each { |n, v|
          if field_name_format(n) =~ name  &&  v =~ regexp
            header[n] = v
          end
        }
        header
      }
    end

    # Match +regexp+ against all field values with a field name of
    # +name+.  If +name+ is nil, all fields are tested.  If +name+ is
    # a Regexp, the field names are matched against the regexp.
    # Returns true if there is a match, false otherwise.
    #
    # See also: #match
    def match?(name, value)
      massage_match_args(name, value) { |name, value|
        match = detect {|n, v|
          n =~ name && v =~ value
        }
        ! match.nil?
      }
    end

    # Sets the "From " line commonly used in the Unix mbox mailbox
    # format.  The +value+ supplied should be the entire "From " line.
    def mbox_from=(value)
      @mbox_from = value
    end

    # Gets the "From " line previously set with mbox_from=, or nil.
    attr_reader :mbox_from

    # This returns the full content type of this message converted to
    # lower case.  If the header does not contain a content-type
    # field, it returns the default content type of <tt>text/plain;
    # charset=us-ascii</tt>.
    def content_type(default = nil)
      if value = self['content-type']
	value.strip.split(/\s*;\s*/)[0].downcase
      else
	if block_given? then yield else default end
      end
    end

    # This returns the main media type for this message converted to
    # lower case.  This is the first portion of the content type.
    # E.g. a content type of <tt>text/plain</tt> has a media type of
    # <tt>text</tt>.
    def media_type(default = nil)
      if value = content_type
        value.split('/')[0]
      else
        if block_given? then yield else default end
      end
    end

    # This returns the media subtype for this message, converted to
    # lower case.  This is the second portion of the content type.
    # E.g. a content type of <tt>text/plain</tt> has a media subtype
    # of <tt>plain</tt>.
    def subtype(default = nil)
      if value = content_type
        value.split('/')[1]
      else
        if block_given? then yield else default end
      end
    end

    # This returns a hash of parameters.  Each key in the hash is the
    # name of the parameter in lower case and each value in the hash
    # is the unquoted parameter value.  If a parameter has no value,
    # its value in the hash will be +true+.
    #
    # If the field or parameter does not exist or it is malformed in a
    # way that makes it impossible to parse, then the return value of
    # the passed block is executed.  If no block is passed, the
    # +default+ value is returned.
    def params(field_name, default = nil)
      if params = params_quoted(field_name)
        params.each { |name, value|
          params[name] = value ? Utils.unquote(value) : nil
        }
      else
	if block_given? then yield field_name else default end
      end
    end

    # This returns the parameter value for the given parameter in the
    # given field.  The value returned is unquoted.
    #
    # If the field or parameter does not exist or it is malformed in a
    # way that makes it impossible to parse, then the return value of
    # the passed block is executed.  If no block is passed, the
    # +default+ value is returned.
    def param(field_name, param_name, default = nil)
      if field?(field_name)
        params = params_quoted(field_name)
        value = params[param_name]
        return Utils.unquote(value) if value
      end
      if block_given? then yield field_name, param_name else default end
    end

    # Set the boundary parameter of this message's Content-Type:
    # header.
    def set_boundary(boundary)
      params = params_quoted('content-type')
      params ||= {}
      params['boundary'] = boundary
      content_type = content_type()
      content_type ||= "multipart/mixed"
      delete('Content-Type')
      add('Content-Type', content_type, nil, params)
    end

    protected

    attr :fields, true

    private

    PARAM_SCAN_RE = %r{
        ;
          |
        [^;"]*"(?:|.*?(?:[^\\]|\\\\))"\s*   # fix fontification "
          |
        [^;]+
    }x

    NAME_VALUE_SCAN_RE = %r{
        =
          |
        [^="]*"(?:.*?(?:[^\\]|\\\\))"   # fix fontification "\s*
          |
        [^=]+
    }x

    def params_quoted(field_name, default = nil)
      if value = self[field_name]
        params = {}
        first = true
	value.scan(PARAM_SCAN_RE) do |param|
          if param != ';'
            unless first
              name, value = param.scan(NAME_VALUE_SCAN_RE).collect do |p|
                if p == '=' then nil else p end
              end.compact
              if name && (name = name.strip.downcase) && name.length > 0
                params[name] = (value || '').strip
              end
            else
              first = false
            end
          end
        end
        params
      else
	if block_given? then yield field_name else default end
      end
    end

    def field_name_strip(field_name)
      field_name.sub(/\s*:.*/, '')
    end

    def field_name_format(field_name)
      field_name_strip(field_name.downcase)
    end

    def massage_match_args(name, value)
      if name.kind_of?(String)
        name = /^#{Regexp.escape(field_name_format(name))}$/i
      elsif name.kind_of?(Regexp)
        unless name.casefold?
          raise ArgumentError, "name regexp is not case insensitive"
        end
      else
        raise ArgumentError, "name not a Regexp or String"
      end
      if value.kind_of?(String)
        name = /#{value}/im
      elsif value.kind_of?(Regexp)
        unless value.casefold?
          raise ArgumentError, "value regexp not multiline or case insensitive"
        end
        unless value.inspect.split('\/').last =~ /m/
          raise ArgumentError, "value regexp not multiline or case insensitive"
        end
      else
        raise ArgumentError, "value not a Regexp or String"
      end
      yield(name, value)
    end

  end
end
