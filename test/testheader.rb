#!/usr/bin/env ruby
#--
#   Copyright (C) 2001, 2002, 2003, 2004, 2007 Matt Armstrong.  All rights reserved.
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

require 'test/testbase'
require 'rmail/header'

class TestRMailHeader < TestBase

  def test_AREF # '[]'
    h = RMail::Header.new
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
    h = RMail::Header.new

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

    # Test that passing in symbols will not get converted into strings
    # strings
    h = RMail::Header.new
    assert_raise(NoMethodError) {
      h[:Kelly] = :the_value
    }

    # Test that the : will be stripped
    h = RMail::Header.new
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
    h1 = RMail::Header.new
    h2 = RMail::Header.new
    assert_equal(h1, h2)
    assert_equal(h2, h1)

    h1['foo'] = 'a'
    h2['FOO'] = 'a'
    h1['bar'] = 'b'
    h2['bar'] = 'b'
    assert_equal(h1, h2)
    assert_equal(h2, h1)

    h1 = RMail::Header.new
    h2 = RMail::Header.new
    h1['foo'] = 'a'
    h2['foo'] = 'b'
    assert(! (h1 == h2))
    assert(! (h2 == h1))

    h1 = RMail::Header.new
    h2 = RMail::Header.new
    h1['foo'] = 'a'
    h2['foo'] = 'a'
    h1.mbox_from = "From bo diddly"
    assert(! (h1 == h2))
    assert(! (h2 == h1))

    h1 = RMail::Header.new
    assert(! (h1 == Object.new))
    assert(! (h1 == Hash.new))
    assert(! (h1 == Array.new))
  end

  def test_address_list_fetch
    h = RMail::Header.new
    assert_equal([], h.address_list_fetch("From"))
    h.add("From", "bob@example.com")
    assert_equal(["bob@example.com"], h.address_list_fetch("From"))
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
    h = RMail::Header.new

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

    # Test that passing in symbol values raises an exception
    h = RMail::Header.new
    assert_raise(NoMethodError) {
      assert_same(h, h.add("bob", :the_value))
    }

    # Test that we can put stuff in arbitrary locations
    h = RMail::Header.new
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
    h = RMail::Header.new
    h.add("name", "value", nil, 'param1' => 'value1', 'param2' => '+value2')
    assert_equal('value; param1=value1; param2="+value2"', h['name'])

    h = RMail::Header.new
    h.add_raw("MIME-Version: 1.0")
    h.add_raw("Content-Type: multipart/alternative; boundary=X")
    assert_match(/\b1\.0\b/, h['mime-version:'])
    assert_not_nil(h.param('content-type', 'boundary'))
    assert_equal("multipart", h.media_type)
  end

  def test_set
    # Test that set works like delete+add

    h = RMail::Header.new
    h.add_raw("Foo: Bar")
    h.set('foo', 'expected')
    assert_equal('expected', h['foo'])
    assert_equal(1, h.length)

    h = RMail::Header.new
    h.set('foo', 'expected')
    assert_equal('expected', h['foo'])
    assert_equal(1, h.length)

  end

  def test_clear
    # Test that we can put stuff in arbitrary locations
    h = RMail::Header.new
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
    h1 = RMail::Header.new
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
    assert_respond_to(h1, :my_singleton_method)
    h2 = h1.dup
    assert(! h2.respond_to?(:my_singleton_method))
  end

  def test_clone
    h1 = RMail::Header.new
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
    h1 = RMail::Header.new
    def h1.my_singleton_method
    end
    assert_respond_to(h1, :my_singleton_method)
    h2 = h1.clone
    assert(!h1.equal?(h2))
    assert_respond_to(h2, :my_singleton_method)
  end

  def test_replace
    h1 = RMail::Header.new
    h1['From'] = "bob@example.net"
    h1['To'] = "sam@example.net"
    h1.mbox_from = "mbox from"

    h2 = RMail::Header.new
    h2['From'] = "sally@example.net"
    h2.mbox_from = "h2 mbox from"

    assert_same(h2, h2.replace(h1))
    assert_equal(h1, h2)
    assert_same(h1['From'], h2['From'])
    assert_same(h1['To'], h2['To'])
    assert_same(h1.mbox_from, h2.mbox_from)

    e = assert_raise(TypeError) {
      h2.replace("hi mom")
    }
    assert_equal('String is not of type RMail::Header', e.message)
  end

  def test_delete
    h = RMail::Header.new
    h['Foo'] = 'bar'
    h['Bazo'] = 'bingo'
    h['Foo'] =  'yo'
    assert_same(h, h.delete('Foo'))
    assert_nil(h['Foo'])
    assert_equal('bingo', h[0])
    assert_equal(1, h.length)
  end

  def test_delete_at
    h = RMail::Header.new
    h['Foo'] = 'bar'
    h['Baz'] = 'bingo'
    h['Foo'] =  'yo'
    assert_same(h, h.delete_at(1))
    assert_equal(2, h.length)
    assert_nil(h['Baz'])
    assert_equal('bar', h[0])
    assert_equal('yo', h[1])

    assert_raise(TypeError) {
      h.delete_at("1")
    }
  end

  def test_delete_if
    h = RMail::Header.new
    h['Foo'] = 'bar'
    h['Baz'] = 'bingo'
    h['Foo'] =  'yo'
    assert_same(h, h.delete_if { |n, v| v =~ /^b/ })
    assert_nil(h['Baz'])
    assert_equal('yo', h['Foo'])
    assert_equal(1, h.length)

    assert_raise(LocalJumpError) {
      h.delete_if
    }
  end

  def each_helper(method)
    h = RMail::Header.new
    h['name1'] = 'value1'
    h['name2'] = 'value2'

    i = 1
    h.send(method) { |n, v|
      assert_equal("name#{i}", n)
      assert_equal("value#{i}", v)
      i += 1
    }

    assert_raise(LocalJumpError) {
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
    h = RMail::Header.new
    h['name1'] = 'value1'
    h['name2'] = 'value2'

    i = 1
    h.send(method) { |n|
      assert_equal("name#{i}", n)
      i += 1
    }

    assert_raise(LocalJumpError) {
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
    h = RMail::Header.new
    h['name1'] = 'value1'
    h['name2'] = 'value2'

    i = 1
    h.each_value { |v|
      assert_equal("value#{i}", v)
      i += 1
    }

    assert_raise(LocalJumpError) {
      h.each_value
    }
  end

  def test_empty?
    h = RMail::Header.new
    assert(h.empty?)
    h['To'] = "president@example.com"
    assert_equal(false, h.empty?)
  end

  def test_fetch
    h = RMail::Header.new
    h['To'] = "bob@example.net"
    h['To'] = "sally@example.net"

    assert_equal("bob@example.net", h.fetch('to'))
    assert_equal(1, h.fetch('notthere', 1))
    assert_equal(2, h.fetch('notthere', 1) { 2 })

    e = assert_raise(ArgumentError) {
      h.fetch(1,2,3)
    }
    assert_equal('wrong # of arguments(3 for 2)', e.message)
  end

  def test_fetch_all
    h = RMail::Header.new
    h['To'] = "bob@example.net"
    h['To'] = "sally@example.net"

    assert_equal([ "bob@example.net", "sally@example.net" ],
                 h.fetch_all('to'))
    assert_equal(1, h.fetch('notthere', 1))
    assert_equal(2, h.fetch('notthere', 1) { 2 })

    e = assert_raise(ArgumentError) {
      h.fetch_all(1,2,3)
    }
    assert_equal('wrong # of arguments(3 for 2)', e.message)
  end

  def field_helper(method)
    h = RMail::Header.new
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

  def test_select_on_empty_header_returns_empty_array
    h = RMail::Header.new
    assert_equal([], h.select("From"))
  end

  def test_select
    h = RMail::Header.new
    h['To'] = 'matt@example.net'
    h['From'] = 'bob@example.net'
    h['Subject'] = 'test_select'
    assert_equal([ [ 'To', 'matt@example.net' ] ],
                 h.select('To'))
    assert_equal([ [ 'To', 'matt@example.net' ],
                   [ 'From', 'bob@example.net' ] ],
                 h.select('To', 'From'))
    assert_equal([], h.select)
  end

  def names_helper(method)
    h = RMail::Header.new
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
    h = RMail::Header.new
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
    h = RMail::Header.new
    assert_equal([ ], h.to_a)
    h['To'] = 'to value'
    h['From'] = 'from value'
    assert_equal([ [ 'To', 'to value' ],
                   [ 'From', 'from value' ] ], h.to_a)
  end

  def test_to_string
    h = RMail::Header.new
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
    h = RMail::Header.new
    assert_instance_of(RMail::Header, h)
    assert_equal(0, h.length)
    assert_nil(h[0])
  end

  def test_mbox_from()
    h = RMail::Header.new
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
  def compare_header(header, expected)
    testcase_desc = "TestCase header: #{header.inspect} " +
      "expected result: #{expected.inspect}"
    count = 0
    header.each_with_index { |value, index|
      count = count.succ
      assert_operator(index, '<', expected.length,
		      "result has too few elements. #{testcase_desc}")
      assert_operator(2, '<=', expected[index].length,
		      "Expected result item must have at last two elements. " +
                      testcase_desc)
      assert_operator(3, '>=', expected[index].length,
		      "Expected result item must have no more than three " +
		      "elements.  " + testcase_desc)
      assert_equal(2, value.length, testcase_desc)

      expected_tag, expected_header = expected[index]
      got_tag, got_header = value

      assert_equal(header[index], got_header, testcase_desc)

      assert_equal(expected_tag, got_tag,
		   "field #{index} has incorrect name.  " + testcase_desc)
      assert_equal(expected_header, got_header,
		   "field #{index} has incorrect line, " +
		   "expected #{expected_header.inspect} got " +
		   "#{got_header.inspect}.  " + testcase_desc)
      assert_equal(header[expected_tag], expected_header, testcase_desc)
    }
    assert_equal(count, expected.length,
                 "result has too few elements " +
                 "(#{count} < #{expected.length}).  " + testcase_desc)
  end

  def verify_match(header, name, value, expected_result)
    h = header.match(name, value)
    assert_kind_of(RMail::Header, h)
    if h.length == 0
      assert_equal(expected_result, nil)
    else
      assert_not_nil(expected_result)
      compare_header(h, expected_result)
    end
  end

  def test_match
    h = RMail::Header.new
    h['To'] = 'bob@example.net'
    h['Cc'] = 'sammy@example.com'
    h['Resent-To'] = 'president@example.com'
    h['Subject'] = 'yoda lives!'

    # First verify argument type checking
    e = assert_raise(ArgumentError) {
      h.match(12, "foo")
    }
    assert_match(/name not a Regexp or String/, e.message)
    assert_nothing_raised {
      h.match(/not_case_insensitive/, "foo")
    }
    e = assert_raise(ArgumentError) {
      h.match(/this is okay/i, 12)
    }
    assert_match(/value not a Regexp or String/, e.message)
    assert_nothing_raised {
      h.match(/this is okay/i, /this_not_multiline_or_insensitive/)
    }
    assert_nothing_raised {
      h.match(/this is okay/i, /this_not_multiline/i)
    }
    assert_nothing_raised {
      h.match(/this is okay/i, /this_not_inesnsitive/m)
    }

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
    h = RMail::Header.new
    h['To'] = 'bob@example.net'
    h['Cc'] = 'sammy@example.com'
    h['Resent-To'] = 'president@example.com'
    h['Subject'] = "yoda\n lives! [bob]\\s"

    # First verify argument type checking
    e = assert_raise(ArgumentError) {
      h.match?(12, "foo")
    }
    assert_match(/name not a Regexp or String/, e.message)
    assert_nothing_raised {
      h.match?(/not_case_insensitive/, "foo")
    }
    e = assert_raise(ArgumentError) {
      h.match?(/this is okay/i, 12)
    }
    assert_match(/value not a Regexp or String/, e.message)
    assert_nothing_raised {
      h.match?(/this is okay/i, /this_not_multiline_or_insensitive/)
    }
    assert_nothing_raised {
      h.match?(/this is okay/i, /this_not_multiline/i)
    }
    assert_nothing_raised {
      h.match?(/this is okay/i, /this_not_inesnsitive/m)
    }

    assert_equal(false, h.match?(/./i, /this will not match anything/im))
    assert_equal(true, h.match?("to", /./im))
    assert_equal(true, h.match?("To", /./im))
    assert_equal(false, h.match?("^to", /./im))
    assert_equal(true, h.match?(/^(to|cc|resent-to)/i, /.*/im))
    assert_equal(true, h.match?('subject', 'yoda'))
    assert_equal(true, h.match?('subject', /yoda\s+lives/))
    assert_equal(true, h.match?('subject', '[bob]\s'))
    assert_equal(true, h.match?('subject', '[BOB]\s'))
  end

  def test_content_type
    h = RMail::Header.new
    assert_equal(nil, h.content_type)

    h['content-type'] = ' text/html; charset=ISO-8859-1'
    assert_equal("text/html", h.content_type)

    h.delete('content-type')
    h['content-type'] = ' foo/html   ; charset=ISO-8859-1'
    assert_equal("foo/html", h.content_type)
  end

  def test_media_type
    h = RMail::Header.new
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
    h = RMail::Header.new
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
      h = RMail::Header.new
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
      h = RMail::Header.new
      h['Content-Disposition'] = 'attachment;
	filename="delete_product_recover_flag.cmd"'
      assert_equal( { "filename" => "delete_product_recover_flag.cmd" },
                   h.params('content-disposition'))
    end

    begin
      h = RMail::Header.new
      h['Content-Disposition'] = 'attachment;
	filename="delete=_product=_recover;_flag;.cmd"'
      assert_equal( { "filename" => "delete=_product=_recover;_flag;.cmd" },
                   h.params('content-disposition'))
    end

    begin
      h = RMail::Header.new
      h['Content-Disposition'] = '  attachment  ;
	filename  =  "trailing_Whitespace.cmd"  '
      assert_equal( { "filename" => "trailing_Whitespace.cmd" },
                   h.params('content-disposition'))
    end

    begin
      h = RMail::Header.new
      h['Content-Disposition'] = ''
      assert_equal({}, h.params('content-disposition'))
    end

    begin
      h = RMail::Header.new
      h['Content-Disposition'] = '   '
      assert_equal({}, h.params('content-disposition'))
    end

    begin
      h = RMail::Header.new
      h['Content-Disposition'] = '='
      assert_equal({}, h.params('content-disposition'))
    end

    begin
      h = RMail::Header.new
      h['Content-Disposition'] = 'ass; param1 = "p1"; param2 = "p2"'
      assert_equal({ 'param1' => 'p1',
                     'param2' => 'p2' }, h.params('content-disposition'))
    end

    begin
      h = RMail::Header.new
      h['Content-Disposition'] = 'ass; Foo = "" ; bar = "asdf"'
      assert_equal({ "foo" => '""',
                     "bar" => "asdf" }, h.params('content-disposition'))
    end
  end

  def test_set_boundary
    begin
      h = RMail::Header.new
      h.set_boundary("b")
      assert_equal("b", h.param('content-type', 'boundary'))
      assert_equal("multipart/mixed", h.content_type)
      assert_equal('multipart/mixed; boundary=b', h['content-type'])
    end

    begin
      h = RMail::Header.new
      h['content-type'] = "multipart/alternative"
      h.set_boundary("b")
      assert_equal("b", h.param('content-type', 'boundary'))
      assert_equal("multipart/alternative", h.content_type)
      assert_equal('multipart/alternative; boundary=b', h['content-type'])
    end

    begin
      h = RMail::Header.new
      h['content-type'] = 'multipart/alternative; boundary="a"'
      h.set_boundary("b")
      assert_equal("b", h.param('content-type', 'boundary'))
      assert_equal("multipart/alternative", h.content_type)
      assert_equal('multipart/alternative; boundary=b', h['content-type'])
    end

  end

  def test_params_random_string
#     find_shortest_failure("],C05w\010O\e]b\">%\023[1{:L1o>B\"|\024fDJ@u{)\\\021\t\036\034)ZJ\034&/+]owh=?{Yc)}vi\000\"=@b^(J'\\,O|4v=\"q,@p@;\037[\"{!Dg*(\010\017WQ]:Q;$\004x]\032\035\003a#\"=;\005@&\003:;({>`y{?<X\025vb\032\037\"\"K8\025u[cb}\001;k', k\a/?xm1$\n_?Z\025t?\001,_?O=\001\003U,Rk<\\\027w]j@?J(5ybTb\006\0032@@4\002JP W,]EH|]\\G\e\003>.p/\022jP\f/4U)\006+\022(<{|.<|]]\032.,N,\016\000\036T,;\\49C>C[{b[v") { |str|
#       h = RMail::Header.new
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
	assert_nothing_raised("failed for string #{string.inspect}") {
          h = RMail::Header.new
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
      h = RMail::Header.new
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
      h = RMail::Header.new
      h['Content-Disposition'] = 'attachment;
	filename="delete_product_recover_flag.cmd"'
      assert_equal('delete_product_recover_flag.cmd',
                   h.param('content-disposition',
                           'filename'))
      assert_nil(h.param('content-disposition', 'notthere'))
    end

    begin
      h = RMail::Header.new
      h['Content-Disposition'] = 'attachment;
	filename="delete=_product=_recover;_flag;.cmd"'
      assert_equal("delete=_product=_recover;_flag;.cmd",
                   h.param('content-disposition', 'filename'))
    end

    begin
      h = RMail::Header.new
      h['Content-Disposition'] = '  attachment  ;
	filename  =  "  trailing_Whitespace.cmd  "  '
      assert_equal("  trailing_Whitespace.cmd  ",
                   h.param('content-disposition', 'filename'))
    end
  end

  def test_date

    begin
      h = RMail::Header.new
      h.add_raw("Date: Sat, 18 Jan 2003 21:00:09 -0700")
      t = h.date
      assert(!t.utc?)
      t.utc
      assert_equal([9, 0, 4, 19, 1, 2003, 0], t.to_a[0, 7])
      assert_match(/Sun, 19 Jan 2003 04:00:09 [+-]0000/, t.rfc2822)
    end

    begin
      h = RMail::Header.new
      h.add_raw("Date: Sat,18 Jan 2003 02:04:27 +0100 (CET)")
      t = h.date
      assert(!t.utc?)
      t.utc
      assert_equal([27, 4, 1, 18, 1, 2003, 6, 18], t.to_a[0, 8])
      assert_match(/Sat, 18 Jan 2003 01:04:27 [+-]0000/, t.rfc2822)
    end

    begin
      h = RMail::Header.new
      # This one is bogus and can't even be parsed.
      h.add_raw("Date: 21/01/2002 09:29:33 Pacific Daylight Time")
      t = assert_nothing_raised {
        h.date
      }
      assert_nil(t)
    end

    begin
      h = RMail::Header.new
      # This time is out of the range that can be represented by a
      # Time object.
      h.add_raw("Date: Sun, 14 Jun 2065 05:51:55 +0200")
      t = assert_nothing_raised {
        h.date
      }
      assert_nil(t)
    end

  end

  def test_date_eq
    h = RMail::Header.new
    t = Time.at(1042949885).utc
    h.date = t
    assert_match(/Sun, 19 Jan 2003 04:18:05 [+-]0000/, h['date'])
  end

  def test_from
    begin
      h = RMail::Header.new
      h.add_raw('From: matt@example.net')
      a = h.from
      assert_kind_of(Array, a)
      assert_kind_of(RMail::Address::List, a)
      assert_equal(1, a.length)
      assert_kind_of(RMail::Address, a.first)
      assert_equal(RMail::Address.new("matt@example.net"), a.first)
    end

    begin
      h = RMail::Header.new
      h.add_raw('From: Matt Armstrong <matt@example.net>,
 Bob Smith <bob@example.com>')
      a = h.from
      assert_kind_of(Array, a)
      assert_kind_of(RMail::Address::List, a)
      assert_equal(2, a.length)
      assert_kind_of(RMail::Address, a[0])
      assert_equal("matt@example.net", a[0].address)
      assert_equal("Matt Armstrong", a[0].display_name)
      assert_kind_of(RMail::Address, a[1])
      assert_equal("bob@example.com", a[1].address)
      assert_equal("Bob Smith", a[1].display_name)
    end

    begin
      h = RMail::Header.new
      a = h.from
      assert_kind_of(Array, a)
      assert_kind_of(RMail::Address::List, a)
      assert_equal(0, a.length)
      assert_nil(h.from.first)
    end
  end

  def common_test_address_list_header_assign(field_name)
    h = RMail::Header.new

    get = field_name.downcase.gsub(/-/, '_')
    assign = get + '='

    h.__send__("#{assign}", "bob@example.net")
    assert_equal(1, h.length)
    assert_equal("bob@example.net", h[field_name])

    h[field_name] = "bob2@example.net"
    assert_equal(2, h.length)
    assert_equal("bob@example.net", h[field_name])
    assert_equal(["bob@example.net", "bob2@example.net"],
                 h.fetch_all(field_name))
    assert_equal(["bob@example.net", "bob2@example.net"],
                 h.__send__("#{get}"))

    h.__send__("#{assign}", "sally@example.net")
    assert_equal(1, h.length)
    assert_equal("sally@example.net", h[field_name])

    h.__send__("#{assign}", "Sally <sally@example.net>, bob@example.invalid (Bob)")
    assert_equal(1, h.length)
    assert_equal(2, h.__send__(get).length)
    assert_equal(%w{ sally bob },
                 h.__send__(get).locals)
    assert_equal([ 'Sally', nil ],
                 h.__send__(get).display_names)
    assert_equal([ 'Sally', 'Bob' ],
                 h.__send__(get).names,
                 "got wrong result for #names")
    assert_equal(%w{ example.net example.invalid },
                 h.__send__(get).domains)
    assert_equal(%w{ sally@example.net bob@example.invalid },
                 h.__send__(get).addresses)
    assert_equal([ "Sally <sally@example.net>", "bob@example.invalid (Bob)" ],
                 h.__send__(get).format)

    h.__send__("#{assign}", RMail::Address.new('Bill <bill@example.net>'))
    assert_equal(1, h.length)
    assert_equal(1, h.__send__(get).length)
    assert_equal(%w{ bill@example.net }, h.__send__(get).addresses)
    assert_equal('bill@example.net', h.__send__(get)[0].address)
    assert_equal('Bill', h.__send__(get)[0].display_name)

    h.__send__("#{assign}", RMail::Address.parse('Bob <bob@example.net>, ' +
                                                 'Sally <sally@example.net>'))
    assert_equal(1, h.length)
    assert_equal(2, h.__send__(get).length)
    assert_equal(%w{ bob@example.net sally@example.net },
                 h.__send__(get).addresses)
    assert_equal('bob@example.net', h.__send__(get)[0].address)
    assert_equal('Bob', h.__send__(get)[0].display_name)
    assert_equal('sally@example.net', h.__send__(get)[1].address)
    assert_equal('Sally', h.__send__(get)[1].display_name)
  end

  def test_from_assign
    common_test_address_list_header_assign('From')
  end

  def test_to_assign
    common_test_address_list_header_assign('To')
  end

  def test_reply_cc_assign
    common_test_address_list_header_assign('Cc')
  end

  def test_reply_bcc_assign
    common_test_address_list_header_assign('Bcc')
  end

  def test_reply_to_assign
    common_test_address_list_header_assign('Reply-To')
  end

  def test_message_id
    h = RMail::Header.new
    h.set('Message-Id', '<foo@bar>')
    assert_equal('<foo@bar>', h.message_id)
  end

  def test_add_message_id
    h = RMail::Header.new
    h.add_message_id

    a = RMail::Address.parse(h.message_id).first
    require 'socket'
    assert_equal(Socket.gethostname + '.invalid', a.domain)
    assert_equal('rubymail', a.local.split('.')[3])
    assert_equal('0', a.local.split('.')[2],
                 "md5 data present for empty header")
    assert_match(/[a-z0-9]{5,6}/, a.local.split('.')[0])
    assert_match(/[a-z0-9]{5,6}/, a.local.split('.')[1])

    h.to = "matt@lickey.com"
    h.delete('message-id')
    h.add_message_id
    a = RMail::Address.parse(h.message_id).first
    assert_equal('70bmbq38pc5q462kl4ikv0mcq', a.local.split('.')[2],
                 "md5 hash wrong for header")
  end

  def test_subject
    h = RMail::Header.new
    h['subject'] = 'hi mom'
    assert_equal('hi mom', h.subject)
    assert_equal('hi mom', h['subject'])
    h.subject = 'hi dad'
    assert_equal(1, h.length)
    assert_equal('hi dad', h['subject'])
    assert_equal('hi dad', h['Subject'])
    assert_equal("Subject: hi dad\n", h.to_s)
  end

  def test_recipients
    %w{ to cc bcc }.each { |field_name|
      h = RMail::Header.new
      h[field_name] = 'matt@lickey.com'
      assert_equal([ 'matt@lickey.com' ], h.recipients )
      h[field_name] = 'bob@lickey.com'
      assert_equal([ 'matt@lickey.com', 'bob@lickey.com' ], h.recipients )
    }

    h = RMail::Header.new
    h.to = [ 'bob@example.net', 'sally@example.net' ]
    h.cc = 'bill@example.net'
    h.bcc = 'samuel@example.net'
    assert_kind_of(RMail::Address::List, h.recipients)
    assert_equal([ 'bill@example.net',
                   'bob@example.net',
                   'sally@example.net',
                   'samuel@example.net' ], h.recipients.sort)

    h = RMail::Header.new
    assert_kind_of(RMail::Address::List, h.recipients)
    assert_equal(0, h.recipients.length)
  end

end
