#!/usr/bin/env ruby
=begin
   Copyright (C) 2001, 2002 Matt Armstrong.  All rights reserved.

   Permission is granted for use, copying, modification, distribution,
   and distribution of modified versions of this work as long as the
   above copyright notice is included.
=end

require 'tests/testbase'
require 'mail/header'

class TestMailHeader < TestBase

  def test_AREF # '[]'
    h = Mail::Header.new
    h['From'] = 'setting1'
    h['From'] = 'setting2'
    h['From'] = 'setting3'

    assert_equal('setting1', h[0])
    assert_equal('setting2', h[1])
    assert_equal('setting3', h[2])
    assert_equal('setting1', h['From'])
    assert_equal('setting1', h['from'])
    assert_equal('setting1', h['FROM'])
    assert_equal('setting1', h['From:'])
    assert_equal('setting1', h['From : '])
    assert_nil(h['From '])
    assert_nil(h[' From '])
    assert_nil(h[' From : '])
  end

  def test_ASET # '[]='

    #
    # Test that the object stores the exact objects we pass it in (at
    # least, when they are strings) and that it freezes them.
    #
    bob = "Bob"
    bob_value = "bobvalue"
    sally = "Sally"
    sally_value = "sallyvalue"
    h = Mail::Header.new

    assert_same(bob_value, h[bob] = bob_value)
    assert_same(sally_value, h[sally] = sally_value)

    h.each_with_index do |pair, index|
      case index
      when 0
	assert_equal(bob, pair[0])
	assert_equal(bob_value, pair[1])
	assert(pair[0].frozen?)
	assert(pair[1].frozen?)
      when 1
	assert_equal(sally, pair[0])
	assert_equal(sally_value, pair[1])
	assert(pair[0].frozen?)
	assert(pair[1].frozen?)
      else
	raise
      end
    end

    # Test that we can pass in symbols and they get converted to
    # strings
    h = Mail::Header.new
    h[:Kelly] = :the_value
    h.each_with_index do |pair, index|
      case index
      when 0
	assert_equal("Kelly", pair[0])
	assert_equal("the_value", pair[1])
	assert(pair[0].frozen?)
	assert(pair[1].frozen?)
      else
	raise
      end
    end

    # Test that the : will be stripped
    h = Mail::Header.new
    h["bob:"] = "bob"
    h["sally : "] = "sally"
    h.each_with_index do |pair, index|
      case index
      when 0
	assert_equal("bob", pair[0])
	assert_equal("bob", pair[1])
      when 1
	assert_equal("sally", pair[0])
	assert_equal("sally", pair[1])
      else
	raise
      end
    end
  end

  def test_EQUAL # '=='
    h1 = Mail::Header.new
    h2 = Mail::Header.new
    assert_equal(h1, h2)
    assert_equal(h2, h1)

    h1['foo'] = 'a'
    h2['foo'] = 'a'
    h1['bar'] = 'b'
    h2['bar'] = 'b'
    assert_equal(h1, h2)
    assert_equal(h2, h1)

    h1 = Mail::Header.new
    h2 = Mail::Header.new
    h1['foo'] = 'a'
    h2['foo'] = 'b'
    assert(! (h1 == h2))
    assert(! (h2 == h1))

    h1 = Mail::Header.new
    h2 = Mail::Header.new
    h1['foo'] = 'a'
    h2['foo'] = 'a'
    h1.mbox_from = "From bo diddly"
    assert(! (h1 == h2))
    assert(! (h2 == h1))

    h1 = Mail::Header.new
    assert(! (h1 == Object.new))
    assert(! (h1 == Hash.new))
    assert(! (h1 == Array.new))
  end

  def test_add
    #
    # Test that the object stores the exact objects we pass it in (at
    # least, when they are strings) and that it freezes them.
    #
    bob = "Bob"
    bob_value = "bobvalue"
    sally = "Sally"
    sally_value = "sallyvalue"
    h = Mail::Header.new

    assert_same(h, h.add(bob, bob_value))
    assert_same(h, h.add(sally, sally_value))

    h.each_with_index do |pair, index|
      case index
      when 0
	assert_equal(bob, pair[0])
	assert_equal(bob_value, pair[1])
	assert(pair[0].frozen?)
	assert(pair[1].frozen?)
      when 1
	assert_equal(sally, pair[0])
	assert_equal(sally_value, pair[1])
	assert(pair[0].frozen?)
	assert(pair[1].frozen?)
      else
	raise
      end
    end

    # Test that we can pass in symbols and they get converted to
    # strings
    h = Mail::Header.new
    assert_same(h, h.add(:Kelly, :the_value))
    h.each_with_index do |pair, index|
      case index
      when 0
	assert_equal("Kelly", pair[0])
	assert_equal("the_value", pair[1])
	assert(pair[0].frozen?)
	assert(pair[1].frozen?)
      else
	raise
      end
    end

    # Test that we can put stuff in arbitrary locations
    h = Mail::Header.new
    assert_same(h, h.add("last", "last value"))
    assert_same(h, h.add("first", "first value", 0))
    assert_same(h, h.add("middle", "middle value", 1))

    h.each_with_index do |pair, index|
      case index
      when 0
        assert_equal("first", pair[0])
        assert_equal("first value", pair[1])
      when 1
        assert_equal("middle", pair[0])
        assert_equal("middle value", pair[1])
      when 2
        assert_equal("last", pair[0])
        assert_equal("last value", pair[1])
      else
	raise
      end
    end

    # Test the params argument
    h = Mail::Header.new
    h.add("name", "value", nil, 'param1' => 'value1', 'param2' => '+value2')
    assert_equal('value; param1=value1; param2="+value2"', h['name'])
  end

  def test_clear
    # Test that we can put stuff in arbitrary locations
    h = Mail::Header.new
    h.add("first", "first value", 0)
    h.add("middle", "middle value", 1)
    h.add("last", "last value")
    h.mbox_from = "mbox from"
    assert_equal(3, h.length)
    assert_same(h, h.clear)
    assert_equal(0, h.length)
    assert_equal(nil, h['first'])
    assert_equal(nil, h['middle'])
    assert_equal(nil, h['last'])
    assert_equal(nil, h[0])
    assert_equal(nil, h[1])
    assert_equal(nil, h[2])
    assert_equal(nil, h.mbox_from)
  end

  def test_dup
    h1 = Mail::Header.new
    h1["field1"] = "field1 value"
    h1.mbox_from = "mbox from"
    h2 = h1.dup
    assert(! h1.equal?(h2))
    assert_equal(h1, h2)
    assert_same(h1.mbox_from, h2.mbox_from)

    h1.each_with_index do |pair, index|
      assert_same(h1[index], h2[index])
      case index
      when 0
        assert_equal("field1", pair[0])
        assert_equal("field1 value", pair[1])
      else
	raise
      end
    end

    h2.mbox_from = "bob"
    assert_equal("mbox from", h1.mbox_from)

    h1["field2"] = "field2 value"
    assert_equal("field2 value", h1["field2"])
    assert_nil(h2["field2"])

    # Make sure singleton methods are not carried over through a dup
    def h1.my_singleton_method
    end
    assert_respond_to(:my_singleton_method, h1)
    h2 = h1.dup
    assert(! h2.respond_to?(:my_singleton_method))
  end

  def test_clone
    h1 = Mail::Header.new
    h1["field1"] = "field1 value"
    h1.mbox_from = "mbox from"
    h2 = h1.clone
    assert(! h1.equal?(h2))
    assert_equal(h1, h2)
    assert_equal(h1.mbox_from, h2.mbox_from)
    assert(! h1.mbox_from.equal?(h2.mbox_from))

    h1.each_with_index do |pair, index|
      assert_equal(h1[index], h2[index])
      assert(! h1[index].equal?(h2[index]))
      case index
      when 0
        assert_equal("field1", pair[0])
        assert_equal("field1 value", pair[1])
      else
	raise
      end
    end

    h2.mbox_from = "bob"
    assert_equal("mbox from", h1.mbox_from)

    h1["field2"] = "field2 value"
    assert_equal("field2 value", h1["field2"])
    assert_nil(h2["field2"])

    # Make sure singleton methods are carried over through a clone
    h1 = Mail::Header.new
    def h1.my_singleton_method
    end
    assert_respond_to(:my_singleton_method, h1)
    h2 = h1.clone
    assert(!h1.equal?(h2))
    assert_respond_to(:my_singleton_method, h2)
  end

  def test_replace
    h1 = Mail::Header.new
    h1['From'] = "bob@example.net"
    h1['To'] = "sam@example.net"
    h1.mbox_from = "mbox from"

    h2 = Mail::Header.new
    h2['From'] = "sally@example.net"
    h2.mbox_from = "h2 mbox from"

    assert_same(h2, h2.replace(h1))
    assert_equal(h1, h2)
    assert_same(h1['From'], h2['From'])
    assert_same(h1['To'], h2['To'])
    assert_same(h1.mbox_from, h2.mbox_from)

    e = assert_exception(TypeError) {
      h2.replace("hi mom")
    }
    assert_equal('String is not of type Mail::Header', e.message)
  end

  def test_delete
    h = Mail::Header.new
    h['Foo'] = 'bar'
    h['Bazo'] = 'bingo'
    h['Foo'] =  'yo'
    assert_same(h, h.delete('Foo'))
    assert_nil(h['Foo'])
    assert_equal('bingo', h[0])
    assert_equal(1, h.length)
  end

  def test_delete_at
    h = Mail::Header.new
    h['Foo'] = 'bar'
    h['Bazo'] = 'bingo'
    h['Foo'] =  'yo'
    assert_same(h, h.delete_at(1))
    assert_nil(h['Bazo'])
    assert_equal('bar', h[0])
    assert_equal('yo', h[1])
    assert_equal(2, h.length)

    assert_exception(TypeError) {
      h.delete_at("1")
    }
  end

  def test_delete_if
    h = Mail::Header.new
    h['Foo'] = 'bar'
    h['Bazo'] = 'bingo'
    h['Foo'] =  'yo'
    assert_same(h, h.delete_if { |n, v| v =~ /^b/ })
    assert_nil(h['Bazo'])
    assert_equal('yo', h['Foo'])
    assert_equal(1, h.length)

    assert_exception(LocalJumpError) {
      h.delete_if
    }
  end

  def each_helper(method)
    h = Mail::Header.new
    h['name1'] = 'value1'
    h['name2'] = 'value2'

    i = 1
    h.send(method) { |n, v|
      assert_equal("name#{i}", n)
      assert_equal("value#{i}", v)
      i += 1
    }

    assert_exception(LocalJumpError) {
      h.send(method)
    }
  end

  def test_each
    each_helper(:each)
  end

  def test_each_pair
    each_helper(:each_pair)
  end

  def each_name_helper(method)
    h = Mail::Header.new
    h['name1'] = 'value1'
    h['name2'] = 'value2'

    i = 1
    h.send(method) { |n|
      assert_equal("name#{i}", n)
      i += 1
    }

    assert_exception(LocalJumpError) {
      h.send(method)
    }
  end

  def test_each_name
    each_name_helper(:each_name)
  end

  def test_each_key
    each_name_helper(:each_key)
  end

  def test_each_value
    h = Mail::Header.new
    h['name1'] = 'value1'
    h['name2'] = 'value2'

    i = 1
    h.each_value { |v|
      assert_equal("value#{i}", v)
      i += 1
    }

    assert_exception(LocalJumpError) {
      h.each_value
    }
  end

  def test_empty?
    h = Mail::Header.new
    assert(h.empty?)
    h['To'] = "president@example.com"
    assert_equal(false, h.empty?)
  end

  def test_fetch
    h = Mail::Header.new
    h['To'] = "bob@example.net"
    h['To'] = "sally@example.net"

    assert_equal("bob@example.net", h.fetch('to'))
    assert_equal(1, h.fetch('notthere', 1))
    assert_equal(2, h.fetch('notthere', 1) { 2 })

    e = assert_exception(ArgumentError) {
      h.fetch(1,2,3)
    }
    assert_equal('wrong # of arguments(3 for 2)', e.message)
  end

  def test_fetch_all
    h = Mail::Header.new
    h['To'] = "bob@example.net"
    h['To'] = "sally@example.net"

    assert_equal([ "bob@example.net", "sally@example.net" ],
                 h.fetch_all('to'))
    assert_equal(1, h.fetch('notthere', 1))
    assert_equal(2, h.fetch('notthere', 1) { 2 })

    e = assert_exception(ArgumentError) {
      h.fetch_all(1,2,3)
    }
    assert_equal('wrong # of arguments(3 for 2)', e.message)
  end

  def field_helper(method)
    h = Mail::Header.new
    h['Subject'] = 'the sky is blue'
    assert(h.send(method, 'Subject'))
    assert_equal(false, h.send(method, 'Return-Path'))
  end

  def test_field?
    field_helper(:field?)
  end

  def test_has_key?
    field_helper(:has_key?)
  end

  def test_include?
    field_helper(:include?)
  end

  def test_member?
    field_helper(:member?)
  end

  def test_key?
    field_helper(:key?)
  end

  def test_select
    h = Mail::Header.new
    h['To'] = 'matt@example.net'
    h['From'] = 'bob@example.net'
    h['Subject'] = 'test_select'

    assert_equal([ [ 'To', 'matt@example.net' ],
                   [ 'From', 'bob@example.net' ] ],
                 h.select('To', 'From'))
    assert_equal([], h.select)
  end

  def names_helper(method)
    h = Mail::Header.new
    assert_equal([], h.send(method))
    h['To'] = 'matt@example.net'
    h['from'] = 'bob@example.net'
    h['SUBJECT'] = 'test_select'
    assert_equal([ 'To', 'from', 'SUBJECT' ], h.send(method))
  end

  def test_names
    names_helper(:names)
  end

  def test_keys
    names_helper(:keys)
  end

  def length_helper(method)
    h = Mail::Header.new
    assert_equal(0, h.send(method))
    h['To'] = 'matt@example.net'
    assert_equal(1, h.send(method))
    h['from'] = 'bob@example.net'
    assert_equal(2, h.send(method))
    h['SUBJECT'] = 'test_select'
    assert_equal(3, h.send(method))
    h.mbox_from = "foo"
    assert_equal(3, h.send(method))
    h.delete('from')
    assert_equal(2, h.send(method))
  end

  def test_length
    length_helper(:length)
  end

  def test_size
    length_helper(:size)
  end

  def test_to_a
    h = Mail::Header.new
    assert_equal([ ], h.to_a)
    h['To'] = 'to value'
    h['From'] = 'from value'
    assert_equal([ [ 'To', 'to value' ],
                   [ 'From', 'from value' ] ], h.to_a)
  end

  def test_to_string
    h = Mail::Header.new
    assert_equal("", h.to_string(true))
    assert_equal("", h.to_string(false))
    assert_equal(h.to_s, h.to_string(true))

    h['To'] = 'matt@example.net'
    assert_equal("To: matt@example.net\n", h.to_string(true))
    assert_equal("To: matt@example.net\n", h.to_string(false))
    assert_equal(h.to_s, h.to_string(true))

    h.mbox_from = "From matt@example.net blah blah"
    assert_equal(<<EOF, h.to_string(true))
From matt@example.net blah blah
To: matt@example.net
EOF
    assert_equal("To: matt@example.net\n", h.to_string(false))
    assert_equal(h.to_s, h.to_string(true))
  end

  def test_s_new
    h = Mail::Header.new
    assert_instance_of(Mail::Header, h)
    assert_equal(0, h.length)
    assert_nil(h[0])
  end

  def test_mbox_from()
    h = Mail::Header.new
    assert_nil(h.mbox_from)

    # FIXME: should do some basic sanity checks on its argument.

    s = "foo bar baz"
    assert_same(s, h.mbox_from = s)
    assert_equal(s, h.mbox_from)

    assert_equal(nil, h.mbox_from = nil)
    assert_equal(nil, h.mbox_from)
  end

  # Compare header contents against an expected result. 'result'
  # should be an array of arrays, with the first element being the
  # required key name and the second element being the whole line.
  def compare_header(header, result)
    index = -1
    header.each_with_index { |value, index|
      assert_operator(index, '<', result.length,
		      "result has too few elements")
      assert_operator(2, '<=', result[index].length,
		      "Expected result item must have at last two elements.")
      assert_operator(3, '>=', result[index].length,
		      "Expected result item must have no more than three " +
		      "elements.")
      assert_equal(2, value.length)

      expected_tag, expected_header = result[index]
      got_tag, got_header = value

      assert_equal(header[index], got_header)

      assert_equal(expected_tag, got_tag,
		   "field #{index} has incorrect name")
      assert_equal(expected_header, got_header,
		   "field #{index} has incorrect line, " +
		   "expected #{expected_header.inspect} got " +
		   "#{got_header.inspect}")
      assert_equal(header[expected_tag], expected_header)
    }
    assert_equal(index + 1, result.length,
	   "result has too few elements (#{index} < #{result.length})")
  end

  def verify_match(header, name, regexp, expected_result)
    h = header.match(name, regexp)
    assert_kind_of(Mail::Header, h)
    if h.length == 0
      assert_equal(nil, expected_result)
    else
      assert_not_nil(expected_result)
      compare_header(h, expected_result)
    end
  end

  def test_match
    h = Mail::Header.new
    h['To'] = 'bob@example.net'
    h['Cc'] = 'sammy@example.com'
    h['Resent-To'] = 'president@example.com'
    h['Subject'] = 'yoda lives!'

    # First verify argument type checking
    e = assert_exception(ArgumentError) {
      h.match(12, "foo")
    }
    assert_match(/name not a Regexp or String/, e.message)
    e = assert_exception(ArgumentError) {
      h.match(/not_case_insensitive/, "foo")
    }
    assert_match(/name regexp is not case insensitive/, e.message)
    e = assert_exception(ArgumentError) {
      h.match(/this is okay/i, 12)
    }
    assert_match(/value not a Regexp or String/, e.message)
    e = assert_exception(ArgumentError) {
      h.match(/this is okay/i, /this_not_multiline_or_insensitive/)
    }
    assert_match(/value regexp not multiline or case insensitive/, e.message)
    e = assert_exception(ArgumentError) {
      h.match(/this is okay/i, /this_not_multiline/i)
    }
    assert_match(/value regexp not multiline or case insensitive/, e.message)
    e = assert_exception(ArgumentError) {
      h.match(/this is okay/i, /this_not_inesnsitive/m)
    }
    assert_match(/value regexp not multiline or case insensitive/, e.message)

    verify_match(h, /./i, /this will not match anything/im, nil)
    verify_match(h, "to", /./im,
		 [ [ 'To', "bob@example.net" ] ])
    verify_match(h, "tO", /./im,
		 [ [ 'To', "bob@example.net" ] ])
    verify_match(h, "To", /./im,
		 [ [ 'To', "bob@example.net" ] ])
    verify_match(h, "^to", /./im, nil)
    verify_match(h, /^(to|cc|resent-to)/i, /.*/im,
		 [ [ 'To', "bob@example.net" ],
		   [ 'Cc', "sammy@example.com" ],
		   [ 'Resent-To', "president@example.com"] ])
  end

  def test_match?
    h = Mail::Header.new
    h['To'] = 'bob@example.net'
    h['Cc'] = 'sammy@example.com'
    h['Resent-To'] = 'president@example.com'
    h['Subject'] = 'yoda lives!'

    # First verify argument type checking
    e = assert_exception(ArgumentError) {
      h.match?(12, "foo")
    }
    assert_match(/name not a Regexp or String/, e.message)
    e = assert_exception(ArgumentError) {
      h.match?(/not_case_insensitive/, "foo")
    }
    assert_match(/name regexp is not case insensitive/, e.message)
    e = assert_exception(ArgumentError) {
      h.match?(/this is okay/i, 12)
    }
    assert_match(/value not a Regexp or String/, e.message)
    e = assert_exception(ArgumentError) {
      h.match?(/this is okay/i, /this_not_multiline_or_insensitive/)
    }
    assert_match(/value regexp not multiline or case insensitive/, e.message)
    e = assert_exception(ArgumentError) {
      h.match?(/this is okay/i, /this_not_multiline/i)
    }
    assert_match(/value regexp not multiline or case insensitive/, e.message)
    e = assert_exception(ArgumentError) {
      h.match?(/this is okay/i, /this_not_inesnsitive/m)
    }
    assert_match(/value regexp not multiline or case insensitive/, e.message)

    assert_equal(false, h.match?(/./i, /this will not match anything/im))
    assert_equal(true, h.match?("to", /./im))
    assert_equal(true, h.match?("To", /./im))
    assert_equal(false, h.match?("^to", /./im))
    assert_equal(true, h.match?(/^(to|cc|resent-to)/i, /.*/im))
  end

  def test_content_type
    h = Mail::Header.new
    assert_equal(nil, h.content_type)

    h['content-type'] = ' text/html; charset=ISO-8859-1'
    assert_equal("text/html", h.content_type)

    h.delete('content-type')
    h['content-type'] = ' foo/html   ; charset=ISO-8859-1'
    assert_equal("foo/html", h.content_type)
  end

  def test_media_type
    h = Mail::Header.new
    assert_nil(h.media_type)
    assert_equal("foo", h.media_type("foo"))
    assert_equal("bar", h.media_type("foo") { "bar" })

    h['content-type'] = ' text/html; charset=ISO-8859-1'
    assert_equal("text", h.media_type)

    h.delete('content-type')
    h['content-type'] = 'foo/html   ; charset=ISO-8859-1'
    assert_equal("foo", h.media_type)
  end

  def test_subtype
    h = Mail::Header.new
    assert_nil(h.subtype)
    assert_equal("foo", h.subtype("foo"))
    assert_equal("bar", h.subtype("foo") { "bar" })

    h['content-type'] = ' text/html; charset=ISO-8859-1'
    assert_equal("html", h.subtype)

    h.delete('content-type')
    h['content-type'] = 'foo/yoda   ; charset=ISO-8859-1'
    assert_equal("yoda", h.subtype)
  end

  def test_params
    begin
      h = Mail::Header.new
      assert_nil(h.params('foo'))
      assert_nil(h.params('foo', nil))

      default = "foo"
      ignore = "ignore"
      assert_same(default, h.params('foo', default))
      assert_same(default, h.params('foo') { |field_name|
                    assert_equal('foo', field_name)
                    default
                  })
      assert_same(default, h.params('foo', ignore) {
                    default
                  })
    end

    begin
      h = Mail::Header.new
      h['Content-Disposition'] = 'attachment;
	filename="delete_product_recover_flag.cmd"'
      assert_equal( { "filename" => "delete_product_recover_flag.cmd" },
                   h.params('content-disposition'))
    end

    begin
      h = Mail::Header.new
      h['Content-Disposition'] = 'attachment;
	filename="delete=_product=_recover;_flag;.cmd"'
      assert_equal( { "filename" => "delete=_product=_recover;_flag;.cmd" },
                   h.params('content-disposition'))
    end

    begin
      h = Mail::Header.new
      h['Content-Disposition'] = '  attachment  ;
	filename  =  "trailing_Whitespace.cmd"  '
      assert_equal( { "filename" => "trailing_Whitespace.cmd" },
                   h.params('content-disposition'))
    end

    begin
      h = Mail::Header.new
      h['Content-Disposition'] = ''
      assert_equal({}, h.params('content-disposition'))
    end

    begin
      h = Mail::Header.new
      h['Content-Disposition'] = '   '
      assert_equal({}, h.params('content-disposition'))
    end

    begin
      h = Mail::Header.new
      h['Content-Disposition'] = '='
      assert_equal({}, h.params('content-disposition'))
    end

    begin
      h = Mail::Header.new
      h['Content-Disposition'] = 'ass; param1 = "p1"; param2 = "p2"'
      assert_equal({ 'param1' => 'p1',
                     'param2' => 'p2' }, h.params('content-disposition'))
    end

    begin
      h = Mail::Header.new
      h['Content-Disposition'] = 'ass; Foo = "" ; bar = "asdf"'
      assert_equal({ "foo" => '""',
                     "bar" => "asdf" }, h.params('content-disposition'))
    end
  end

  def test_set_boundary
    begin
      h = Mail::Header.new
      h.set_boundary("b")
      assert_equal("b", h.param('content-type', 'boundary'))
      assert_equal("multipart/mixed", h.content_type)
      assert_equal('multipart/mixed; boundary=b', h['content-type'])
    end

    begin
      h = Mail::Header.new
      h['content-type'] = "multipart/alternative"
      h.set_boundary("b")
      assert_equal("b", h.param('content-type', 'boundary'))
      assert_equal("multipart/alternative", h.content_type)
      assert_equal('multipart/alternative; boundary=b', h['content-type'])
    end

    begin
      h = Mail::Header.new
      h['content-type'] = 'multipart/alternative; boundary="a"'
      h.set_boundary("b")
      assert_equal("b", h.param('content-type', 'boundary'))
      assert_equal("multipart/alternative", h.content_type)
      assert_equal('multipart/alternative; boundary=b', h['content-type'])
    end

  end

  def test_params_random_string
#     find_shortest_failure("],C05w\010O\e]b\">%\023[1{:L1o>B\"|\024fDJ@u{)\\\021\t\036\034)ZJ\034&/+]owh=?{Yc)}vi\000\"=@b^(J'\\,O|4v=\"q,@p@;\037[\"{!Dg*(\010\017WQ]:Q;$\004x]\032\035\003a#\"=;\005@&\003:;({>`y{?<X\025vb\032\037\"\"K8\025u[cb}\001;k', k\a/?xm1$\n_?Z\025t?\001,_?O=\001\003U,Rk<\\\027w]j@?J(5ybTb\006\0032@@4\002JP W,]EH|]\\G\e\003>.p/\022jP\f/4U)\006+\022(<{|.<|]]\032.,N,\016\000\036T,;\\49C>C[{b[v") { |str|
#       h = Mail::Header.new
#       h['header'] = str
#       h.params('header')
#     }

    0.upto(25) {
      specials = '()<>@,;:\\"/[]?='
      strings = [(0..rand(255)).collect {rand(127).chr}.to_s,
	(0..255).collect {rand(255).chr}.to_s,
	(0..255).collect {
	  r = rand(specials.length * 5)
	  case r
	  when 0 .. specials.length - 1
	    specials[r].chr
	  else
	    rand(127).chr
	  end
	}.to_s ]
      strings.each {|string|
	assert_no_exception("failed for string #{string.inspect}") {
          h = Mail::Header.new
          h['header'] = string
          params = h.params('header')
          params.each { |name, value|
            assert_kind_of(String, name)
            assert(! ("" == name) )
            assert_kind_of(String, value)
          }
	}
      }
    }
  end

  def test_param
    begin
      h = Mail::Header.new
      assert_nil(h.param('bar', 'foo'))
      assert_nil(h.param('bar', 'foo', nil))

      default = "foo"
      ignore = "ignore"
      assert_same(default, h.param('bar', 'foo', default))
      assert_same(default, h.param('bar', 'foo') { |field_name, param_name|
                    assert_equal('bar', field_name)
                    assert_equal('foo', param_name)
                    default
                  })
      assert_same(default, h.param('bar', 'foo', ignore) {
                    default
                  })
    end

    begin
      h = Mail::Header.new
      h['Content-Disposition'] = 'attachment;
	filename="delete_product_recover_flag.cmd"'
      assert_equal('delete_product_recover_flag.cmd',
                   h.param('content-disposition',
                           'filename'))
      assert_nil(h.param('content-disposition', 'notthere'))
    end

    begin
      h = Mail::Header.new
      h['Content-Disposition'] = 'attachment;
	filename="delete=_product=_recover;_flag;.cmd"'
      assert_equal("delete=_product=_recover;_flag;.cmd",
                   h.param('content-disposition', 'filename'))
    end

    begin
      h = Mail::Header.new
      h['Content-Disposition'] = '  attachment  ;
	filename  =  "  trailing_Whitespace.cmd  "  '
      assert_equal("  trailing_Whitespace.cmd  ",
                   h.param('content-disposition', 'filename'))
    end
  end
end
