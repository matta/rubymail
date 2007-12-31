#--
#   Copyright (c) 2001, 2002, 2003, 2004 Matt Armstrong.  All rights
#   reserved.
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
# Implements the RMail::Header class.
require 'rmail/utils'
require 'rmail/address'
require 'digest/md5'
require 'time'

module RMail

  # A class that supports the reading, writing and manipulation of
  # RFC2822 mail headers.

  # =Overview
  #
  # The RMail::Header class supports the creation and manipulation of
  # RFC2822 mail headers.
  #
  # A mail header is a little bit like a Hash.  The fields are keyed
  # by a string field name.  It is also a little bit like an Array,
  # since the fields are in a specific order.  This class provides
  # many of the methods of both the Hash and Array class.  It also
  # includes the Enumerable module.
  #
  # =Terminology
  #
  # header:: The entire header.  Each RMail::Header object is one
  #          mail header.
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
  # such as #each process the headers in this order.
  #
  # When field names or values are added to the object they are
  # frozen.  This helps prevent accidental modification to what is
  # stored in the object.
  class Header
    include Enumerable

    class Field                 # :nodoc:
      # fixme, document methadology for this (RFC2822)
      EXTRACT_FIELD_NAME_RE = /\A([^\x00-\x1f\x7f-\xff :]+):\s*/o

      class << self
        def parse(field)
          field = field.to_str
          if field =~ EXTRACT_FIELD_NAME_RE
            [ $1, $'.chomp ]
          else
            [ "", Field.value_strip(field) ]
          end
        end
      end

      def initialize(name, value = nil)
        if value
          @name = Field.name_strip(name.to_str).freeze
          @value = Field.value_strip(value.to_str).freeze
          @raw = nil
        else
          @raw = name.to_str.freeze
          @name, @value = Field.parse(@raw)
          @name.freeze
          @value.freeze
        end
      end

      attr_reader :name, :value, :raw

      def ==(other)
        other.kind_of?(self.class) &&
          @name.downcase == other.name.downcase &&
          @value == other.value
      end

      def Field.name_canonicalize(name)
        name_strip(name.to_str).downcase
      end

      private

      def Field.name_strip(name)
        name.sub(/\s*:.*/, '')
      end

      def Field.value_strip(value)
        if value.frozen?
          value = value.dup
        end
        value.strip!
        value
      end

    end

    # Creates a new empty header object.
    def initialize()
      clear()
    end

    # Return the value of the first matching field of a field name, or
    # nil if none found.  If passed a Fixnum, returns the header
    # indexed by the number.
    def [](name_or_index)
      if name_or_index.kind_of? Fixnum
        temp = @fields[name_or_index]
        temp = temp.value unless temp.nil?
      else
        name = Field.name_canonicalize(name_or_index)
        result = detect { |n, v|
          if n.downcase == name then true else false end
        }
        if result.nil? then nil else result[1] end
      end
    end

    # Creates a copy of this header object.  A new RMail::Header is
    # created and the instance data is copied over.  However, the new
    # object will still reference the same strings held in the
    # original object.  Since these strings are frozen, this usually
    # won't matter.
    def dup
      h = super
      h.fields = @fields.dup
      h.mbox_from = @mbox_from
      h
    end

    # Creates a complete copy of this header object, including any
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

    # Replaces the contents of this header with that of another header
    # object.  Returns self.
    def replace(other)
      unless other.kind_of?(RMail::Header)
        raise TypeError, "#{other.class.to_s} is not of type RMail::Header"
      end
      temp = other.dup
      @fields = temp.fields
      @mbox_from = temp.mbox_from
      self
    end

    # Return the number of fields in this object.
    def length
      @fields.length
    end
    alias size length

    # Return the value of the first matching field of a given name.
    # If there is no such field, the value returned by the supplied
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
      name = Field.name_canonicalize(name.to_str)
      delete_if { |n, v|
        n.downcase == name
      }
      self
    end

    # Deletes the field at the specified index and returns its value.
    def delete_at(index)
      @fields.delete_at(index)
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

    # Executes block once for each field in the header, passing the
    # key and value as parameters.
    #
    # Returns self.
    def each                    # yields: name, value
      @fields.each { |i|
        yield [i.name, i.value]
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
        name = Field.name_canonicalize(name)
        result.concat(find_all { |n, v|
                        n.downcase == name
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
      value = value.to_str
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
      field = Field.new(name, value)
      index ||= @fields.length
      @fields[index, 0] = field
      self
    end

    # Add a new field as a raw string together with a parsed
    # name/value.  This method is used mainly by the parser and
    # regular programs should stick to #add.
    def add_raw(raw)
      @fields << Field.new(raw)
      self
    end

    # First delete any fields with +name+, then append a new field
    # with +name+, +value+, and +params+ as in #add.
    def set(name, value, params = nil)
      delete(name)
      add(name, value, nil, params)
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
      return other.kind_of?(self.class) &&
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
      @fields.each { |field|
        if field.raw
          s << field.raw
        else
          s << field.name
          s << ': '
          s << field.value
        end
        s << "\n" unless s[-1] == ?\n
      }
      s
    end

    # Determine if there is any fields that match the given +name+ and
    # +value+.
    #
    # If +name+ is a String, all fields of that name are tested.  If
    # +name+ is a Regexp the field names are matched against the
    # regexp (the field names are converted to lower case first).  Use
    # the regexp // if you want to test all field names.
    #
    # If +value+ is a String, it is converted to a case insensitive
    # Regexp that matches the string.  Otherwise, it must be a Regexp.
    # Note that the field value may be folded across many lines, so
    # you should use a multi-line Regexp.  Also consider using a case
    # insensitive Regexp.  Use the regexp // if you want to match all
    # possible field values.
    #
    # Returns true if there is a match, false otherwise.
    #
    # Example:
    #
    #    if h.match?('x-ml-name', /ruby-dev/im)
    #      # do something
    #    end
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

    # Find all fields that match the given +name and +value+.
    #
    # If +name+ is a String, all fields of that name are tested.  If
    # +name+ is a Regexp, the field names are matched against the
    # regexp (the field names are converted to lower case first).  Use
    # the regexp // if you want to test all field names.
    #
    # If +value+ is a String, it is converted to a case insensitive
    # Regexp that matches the string.  Otherwise, it must be a Regexp.
    # Note that the field value may be folded across many lines, so
    # you may need to use a multi-line Regexp.  Also consider using a
    # case insensitive Regexp.  Use the regexp // if you want to match
    # all possible field values.
    #
    # Returns a new RMail::Header holding all matching headers.
    #
    # Examples:
    #
    #  received = header.match('Received', //)
    #  destinations = header.match(/^(to|cc|bcc)$/, //)
    #  bigfoot_received = header.match('received',
    #                                  /from.*by.*bigfoot\.com.*LiteMail/im)
    #
    # See also: #match?
    def match(name, value)
      massage_match_args(name, value) { |name, value|
        header = RMail::Header.new
        found = each { |n, v|
          if n.downcase =~ name  &&  value =~ v
            header[n] = v
          end
        }
        header
      }
    end

    # Sets the "From " line commonly used in the Unix mbox mailbox
    # format.  The +value+ supplied should be the entire "From " line.
    def mbox_from=(value)
      @mbox_from = value
    end

    # Gets the "From " line previously set with mbox_from=, or nil.
    def mbox_from
      @mbox_from
    end

    # This returns the full content type of this message converted to
    # lower case.
    #
    # If there is no content type header, returns the passed block is
    # executed and its return value is returned.  If no block is passed,
    # the value of the +default+ argument is returned.
    def content_type(default = nil)
      if value = self['content-type']
	value.strip.split(/\s*;\s*/)[0].downcase
      else
	if block_given?
          yield
        else
          default
        end
      end
    end

    # This returns the main media type for this message converted to
    # lower case.  This is the first portion of the content type.
    # E.g. a content type of <tt>text/plain</tt> has a media type of
    # <tt>text</tt>.
    #
    # If there is no content type field, returns the passed block is
    # executed and its return value is returned.  If no block is
    # passed, the value of the +default+ argument is returned.
    def media_type(default = nil)
      if value = content_type
        value.split('/')[0]
      else
        if block_given?
          yield
        else
          default
        end
      end
    end

    # This returns the media subtype for this message, converted to
    # lower case.  This is the second portion of the content type.
    # E.g. a content type of <tt>text/plain</tt> has a media subtype
    # of <tt>plain</tt>.
    #
    # If there is no content type field, returns the passed block is
    # executed and its return value is returned.  If no block is passed,
    # the value of the +default+ argument is returned.
    def subtype(default = nil)
      if value = content_type
        value.split('/')[1]
      else
        if block_given? then
          yield
        else
          default
        end
      end
    end

    # This returns a hash of parameters.  Each key in the hash is the
    # name of the parameter in lower case and each value in the hash
    # is the unquoted parameter value.  If a parameter has no value,
    # its value in the hash will be +true+.
    #
    # If the field or parameter does not exist or it is malformed in a
    # way that makes it impossible to parse, then the passed block is
    # executed and its return value is returned.  If no block is
    # passed, the value of the +default+ argument is returned.
    def params(field_name, default = nil)
      if params = params_quoted(field_name)
        params.each { |name, value|
          params[name] = value ? Utils.unquote(value) : nil
        }
      else
	if block_given?
          yield field_name
        else
          default
        end
      end
    end

    # This returns the parameter value for the given parameter in the
    # given field.  The value returned is unquoted.
    #
    # If the field or parameter does not exist or it is malformed in a
    # way that makes it impossible to parse, then the passed block is
    # executed and its return value is returned.  If no block is
    # passed, the value of the +default+ argument is returned.
    def param(field_name, param_name, default = nil)
      if field?(field_name)
        params = params_quoted(field_name)
        value = params[param_name]
        return Utils.unquote(value) if value
      end
      if block_given?
        yield field_name, param_name
      else
        default
      end
    end

    # Set the boundary parameter of this message's Content-Type:
    # field.
    def set_boundary(boundary)
      params = params_quoted('content-type')
      params ||= {}
      params['boundary'] = boundary
      content_type = content_type()
      content_type ||= "multipart/mixed"
      delete('Content-Type')
      add('Content-Type', content_type, nil, params)
    end

    # Return the value of the Date: field, parsed into a Time
    # object.  Returns nil if there is no Date: field or the field
    # value could not be parsed.
    def date
      if value = self['date']
        begin
          # Rely on Ruby's standard time.rb to parse the time.
          (Time.rfc2822(value) rescue Time.parse(value)).localtime
        rescue
          # Exceptions during time parsing just cause nil to be
          # returned.
        end
      end
    end

    # Deletes any existing Date: fields and appends a new one
    # corresponding to the given Time object.
    def date=(time)
      delete('Date')
      add('Date', time.rfc2822)
    end

    # Returns the value of the From: header as an Array of
    # RMail::Address objects.
    #
    # See #address_list_fetch for details on what is returned.
    #
    # This method does not return a single RMail::Address value
    # because it is legal to have multiple addresses in a From:
    # header.
    #
    # This method always returns at least the empty list.  So if you
    # are always only interested in the first from address (most
    # likely the case), you can safely say:
    #
    #    header.from.first
    def from
      address_list_fetch('from')
    end

    # Sets the From: field to the supplied address or addresses.
    #
    # See #address_list_assign for information on valid values for
    # +addresses+.
    #
    # Note that the From: header usually contains only one address,
    # but it is legal to have more than one.
    def from=(addresses)
      address_list_assign('From', addresses)
    end

    # Returns the value of the To: field as an Array of RMail::Address
    # objects.
    #
    # See #address_list_fetch for details on what is returned.
    def to
      address_list_fetch('to')
    end

    # Sets the To: field to the supplied address or addresses.
    #
    # See #address_list_assign for information on valid values for
    # +addresses+.
    def to=(addresses)
      address_list_assign('To', addresses)
    end

    # Returns the value of the Cc: field as an Array of RMail::Address
    # objects.
    #
    # See #address_list_fetch for details on what is returned.
    def cc
      address_list_fetch('cc')
    end

    # Sets the Cc: field to the supplied address or addresses.
    #
    # See #address_list_assign for information on valid values for
    # +addresses+.
    def cc=(addresses)
      address_list_assign('Cc', addresses)
    end

    # Returns the value of the Bcc: field as an Array of
    # RMail::Address objects.
    #
    # See #address_list_fetch for details on what is returned.
    def bcc
      address_list_fetch('bcc')
    end

    # Sets the Bcc: field to the supplied address or addresses.
    #
    # See #address_list_assign for information on valid values for
    # +addresses+.
    def bcc=(addresses)
      address_list_assign('Bcc', addresses)
    end

    # Returns the value of the Reply-To: header as an Array of
    # RMail::Address objects.
    def reply_to
      address_list_fetch('reply-to')
    end

    # Sets the Reply-To: field to the supplied address or addresses.
    #
    # See #address_list_assign for information on valid values for
    # +addresses+.
    def reply_to=(addresses)
      address_list_assign('Reply-To', addresses)
    end

    # Returns the value of this object's Message-Id: field.
    def message_id
      self['message-id']
    end

    # Sets the value of this object's Message-Id: field to a new
    # random value.
    #
    # If you don't supply a +fqdn+ (fully qualified domain name) then
    # one will be randomly generated for you.  If a valid address
    # exists in the From: field, its domain will be used as a basis.
    #
    # Part of the randomness in the header is taken from the header
    # itself, so it is best to call this method after adding other
    # fields to the header -- especially those that make it unique
    # (Subject:, To:, Cc:, etc).
    def add_message_id(fqdn = nil)

      # If they don't supply a fqdn, we supply one for them.
      #
      # First grab the From: field and see if we can use a domain from
      # there.  If so, use that domain name plus the hash of the From:
      # field's value (this guarantees that bob@example.com and
      # sally@example.com will never have clashes).
      #
      # If there is no From: field, grab the current host name and use
      # some randomness from Ruby's random number generator.  Since
      # Ruby's random number generator is fairly good this will
      # suffice so long as it is seeded corretly.
      #
      # P.S. There is no portable way to get the fully qualified
      # domain name of the current host.  Those truly interested in
      # generating "correct" message-ids should pass it in.  We
      # generate a hopefully random and unique domain name.
      unless fqdn
        unless fqdn = from.domains.first
          require 'socket'
          fqdn = sprintf("%s.invalid", Socket.gethostname)
        end
      else
        raise ArgumentError, "fqdn must have at least one dot" unless
          fqdn.index('.')
      end

      # Hash the header we have so far.
      md5 = Digest::MD5.new
      starting_digest = md5.digest
      @fields.each { |f|
        if f.raw
          md5.update(f.raw)
        else
          md5.update(f.name) if f.name
          md5.update(f.value) if f.value
        end
      }
      if (digest = md5.digest) == starting_digest
        digest = 0
      end

      set('Message-Id', sprintf("<%s.%s.%s.rubymail@%s>",
                                base36(Time.now.to_i),
                                base36(rand(MESSAGE_ID_MAXRAND)),
                                base36(digest),
                                fqdn))
    end

    # Return the subject of this message.
    def subject
      self['subject']
    end

    # Set the subject of this message
    def subject=(string)
      set('Subject', string)
    end

    # Returns an RMail::Address::List array holding all the recipients
    # of this message.  This uses the contents of the To, Cc, and Bcc
    # fields.  Duplicate addresses are eliminated.
    def recipients
      RMail::Address::List.new([ to, cc, bcc ].flatten.uniq)
    end

    # Retrieve a given field's value as an RMail::Address::List of
    # RMail::Address objects.
    #
    # This method is used to implement many of the convenience methods
    # such as #from, #to, etc.
    def address_list_fetch(field_name)
      if values = fetch_all(field_name, nil)
        list = nil
        values.each { |value|
          if list
            list.concat(Address.parse(value))
          else
            list = Address.parse(value)
          end
        }
        if list and !list.empty?
          list
        end
      end or RMail::Address::List.new
    end

    # Set a given field to a list of supplied +addresses+.
    #
    # The +addresses+ may be a String, RMail::Address, or Array.  If a
    # String, it is parsed for valid email addresses and those found
    # are used.  If an RMail::Address, the result of
    # RMail::Address#format is used.  If an Array, each element of the
    # array must be either a String or RMail::Address and is treated
    # as above.
    #
    # This method is used to implement many of the convenience methods
    # such as #from=, #to=, etc.
    def address_list_assign(field_name, addresses)
      if addresses.kind_of?(Array)
        value = addresses.collect { |e|
          if e.kind_of?(RMail::Address)
            e.format
          else
            RMail::Address.parse(e.to_str).collect { |a|
              a.format
            }
          end
        }.flatten.join(", ")
        set(field_name, value)
      elsif addresses.kind_of?(RMail::Address)
        set(field_name, addresses.format)
      else
        address_list_assign(field_name,
                            RMail::Address.parse(addresses.to_str))
      end
    end

    protected

    attr :fields, true

    private

    MESSAGE_ID_MAXRAND = 0x7fffffff

    def string2num(string)
      temp = 0
      string.reverse.each_byte { |b|
        temp <<= 8
        temp |= b
      }
      return temp
    end

    BASE36 = "0123456789abcdefghijklmnopqrstuvwxyz"
    def base36(number)
      if number.kind_of?(String)
        number = string2num(number)
      end
      raise ArgumentError, "need non-negative number" if number < 0
      return "0" if number == 0
      result = ""
      while number > 0
        number, remainder = number.divmod(36)
        result << BASE36[remainder]
      end
      return result.reverse!
    end

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

    def massage_match_args(name, value)
      case name
      when String
        name = /^#{Regexp.escape(Field.name_strip(name))}$/i
      when Regexp
      else
        raise ArgumentError,
          "name not a Regexp or String: #{name.class}:#{name.inspect}"
      end
      case value
      when String
        value = Regexp.new(Regexp.escape(value), Regexp::IGNORECASE)
      when Regexp
      else
        raise ArgumentError, "value not a Regexp or String"
      end
      yield(name, value)
    end
  end
end
