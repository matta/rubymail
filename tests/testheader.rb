#!/usr/bin/env ruby
=begin
   Copyright (C) 2001, 2002 Matt Armstrong.  All rights reserved.

   Permission is granted for use, copying, modification, distribution,
   and distribution of modified versions of this work as long as the
   above copyright notice is included.
=end

require 'tests/testbase'
require 'mail/header'

class TestMail__Header < TestBase

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


#   def test_shift
#     assert_fail("untested")
#   end

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

#   def test_unshift
#     assert_fail("untested")
#   end

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

#   # Read a header from a file and compare against desired results.
#   # 'file' is just a filename, 'result' should be as in compare_header
#   # (above)
#   def read_header_and_compare(string, result)
#     tf = Tempfile.new("headers", scratch_dir)
#     tf.write(string)
#     tf.flush
#     tf.seek(0, IO::SEEK_SET)

#     # Here we create an object that only has the API of Object + the
#     # each_line method.  This way, we can be sure that the
#     # Mail::Header object uses only each_line to access the data.
#     proxy = Object.new
#     proxy.instance_eval {
#       @file = tf
#     }
#     def proxy.each_line
#       while line = @file.gets
# 	yield line
#       end
#     end

#     h = Mail::Header.new(proxy)
    
#     tf.close(true)
#     compare_header(h, result)
#   end
  
#   def test_AREF()
#     h = Mail::Header.new
#     h.add('first', 'this is the first line')
#     e = assert_exception(TypeError) {
#       h[Object.new]
#     }
#     assert_kind_of(Exception, e)
#     assert_match(/wanted.*String, got.*Object/, e.message)

#     e = assert_exception(TypeError) {
#       h[[2,3,4]]
#     }
#     assert_kind_of(Exception, e)
#     assert_match(/wanted.*String, got.*Array/, e.message)

#     h = Mail::Header.new
#     h.add('duplicate', 'this is the first of two')
#     h.add('duplicate', 'this is the second of two')
#     assert_equal("duplicate: this is the first of two\n", h['duplicate'])
#     assert_equal("this is the first of two\n", h.get('duplicate'))

#     assert_equal("duplicate: this is the first of two\n", h[-2])
#     assert_equal("duplicate: this is the second of two\n", h[-1])
#     assert_equal(nil, h[-3])
#     assert_equal(nil, h[2])
#   end
  

#   def test_basic_headers()
#     expected = [
#       [ 'from', 'From: test@example.com' + "\n", "test@example.com\n" ]
#     ]
#     data = <<EOF
# From: test@example.com

# EOF
#     read_header_and_compare(data, expected)

#     expected = [
#       [ 'from', "From: test@example.com\n", "test@example.com\n" ],
#       [ 'to', "To: someguy@example.com\n", "someguy@example.com\n" ],
#     ]
#     data = <<EOF
# From: test@example.com
# To: someguy@example.com

# EOF
#     read_header_and_compare(data, expected)

#     expected = [
#       [ 'from', "frOm: test@example.com\n", "test@example.com\n" ],
#       [ 'to', "tO: someguy@example.com\n", "someguy@example.com\n" ],
#       [ 'rtfm-url-helper', "rTFm-uRL-helper: http://www.faqs.org\n",
# 	"http://www.faqs.org\n" ]
#     ]
#     data = <<EOF
# frOm: test@example.com
# tO: someguy@example.com
# rTFm-uRL-helper: http://www.faqs.org

# EOF
#     read_header_and_compare(data, expected)

#     expected = [
#       [ 'from', "frOm: test@example.com\n", "test@example.com\n" ],
#       [ 'to', "tO: someguy@example.com,\n someotherguy@example.com\n",
# 	"someguy@example.com,\n someotherguy@example.com\n" ],
#       [ 'rtfm-url-helper', "rTFm-uRL-helper: http://www.faqs.org\n",
# 	"http://www.faqs.org\n" ]
#     ]
#     data = <<EOF
# frOm: test@example.com
# tO: someguy@example.com,
#  someotherguy@example.com
# rTFm-uRL-helper: http://www.faqs.org

# EOF
#     read_header_and_compare(data, expected)

#     expected = [
#       [ 'from', "frOm: test@example.com\n", "test@example.com\n" ],
#       [ 'to', "tO: someguy@example.com,\n  someotherguy@example.com,\n" +
# 	"  \n  thirdguy@example.com\n",
# 	"someguy@example.com,\n  someotherguy@example.com,\n" +
# 	"  \n  thirdguy@example.com\n"],
#       [ 'rtfm-url-helper', "rTFm-uRL-helper: http://www.faqs.org\n",
# 	"http://www.faqs.org\n" ]
#     ]
#     data = <<EOF
# frOm: test@example.com
# tO: someguy@example.com,
#   someotherguy@example.com,
  
#   thirdguy@example.com
# rTFm-uRL-helper: http://www.faqs.org

# EOF
#     read_header_and_compare(data, expected)    
#   end

#   def test_bogus_headers()
#     expected = [
#       [ 'from', 'From: test@example.test' + "\n", "test@example.test\n" ]
#     ]
#     data = <<EOF
# From: test@example.test
# "this is not a real header"

# EOF
#     read_header_and_compare(data, expected)

#     expected = [
#       [ 'from', 'From: test@example.com' + "\n", "test@example.com\n" ],
#       [ 'subject', 'Subject: a subject' + "\n", "a subject\n" ]
#     ]
#     data = <<EOF
# From: test@example.com
# "this is not a real header"
# Subject: a subject

# EOF
#     read_header_and_compare(data, expected)

#     expected = [
#       [ 'from', 'From: test@example.com' + "\n", "test@example.com\n" ],
#       [ 'subject', 'Subject: a subject' + "\n", "a subject\n" ]
#     ]
#     data = <<EOF
# From: test@example.com
# "this is not a real header"
#     also not a real header
# Subject: a subject

# EOF
#     read_header_and_compare(data, expected)
#   end

#   def test_add()
#     h = Mail::Header.new
#     h.add('first', 'this is the first line')
#     assert_equal("first: this is the first line\n", h['first:'],
# 		 "fetch of h['first:'] failed")
#     assert_equal("first: this is the first line\n", h['First'],
# 		 "fetch of h['First'] failed")
#     h.add('second:', 'this is the second line')
#     assert_equal("second: this is the second line\n", h['SeCoND:'],
# 		 "basic add failed")
#     h.add('third  :', "this is the third line\n")
#     assert_equal("third: this is the third line\n", h['third'],
# 		 "basic add failed")
    
#     expected = [
#       [ 'first', "first: this is the first line\n",
# 	"this is the first line\n" ],
#       [ 'second', "second: this is the second line\n",
# 	"this is the second line\n" ],
#       [ 'third', "third: this is the third line\n",
# 	"this is the third line\n" ]
#     ]
#     compare_header(h, expected)

#     # text field name (tag) extraction from the line
#     h.add(nil, "Fourth: this is the fourth line")
#     expected.push(['fourth', "Fourth: this is the fourth line\n",
# 		  "this is the fourth line\n"])
#     compare_header(h, expected)

#     # insert in the middle
#     h.add(nil, "just-after-first: this is just after the first", 1)
#     expected[1,0] = [
#       ['just-after-first',
# 	"just-after-first: this is just after the first\n",
# 	"this is just after the first\n" ]
#     ]
#     compare_header(h, expected)

#     # insert at the very beginning
#     h.add(nil, "new-first: this the new first", 0)
#     expected.unshift(['new-first', "new-first: this the new first\n",
# 		       "this the new first\n"])
#     compare_header(h, expected)

#     # lame way to append
#     h.add(nil, "last: this is the last header", 999)
#     expected.push(['last', "last: this is the last header\n",
# 		  "this is the last header\n"])
#     compare_header(h, expected)

#     # append a folded line
#     h.add(nil, "tO: someguy@example.com,\n someotherguy@example.com\n")
#     expected.push(['to',
# 		    "tO: someguy@example.com,\n someotherguy@example.com\n",
# 		    "someguy@example.com,\n someotherguy@example.com\n"])
#     compare_header(h, expected)

#     # APPEND an invalid line
#     assert_exception(ArgumentError, "failed to detect invalid line") {
#       h.add(nil,
# 	    "invalid: someguy@example.com,\nsomeotherguy@example.com\n")
#     }
#     compare_header(h, expected)
#   end

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

end
