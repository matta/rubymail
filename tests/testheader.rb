#!/usr/bin/env ruby
#
#   Copyright (c) 2001 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

require 'tests/testbase'
require 'mail/header'
require 'tempfile'

class TestMailHeader < TestBase

  def new_header(string = nil)
    string ||= <<-EOF
    To: bob@example.net
    Cc: sammy@example.com
    Resent-To: president@example.com
    Subject: yoda lives!
    
    EOF
    header = string_as_file(string) { |file|
      Mail::Header.new(file)
    }
    assert_equal(4, header.size)
    assert_equal(header.length, header.size)
    header
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

      expected_tag, expected_header, expected_stripped = result[index]
      got_tag, got_header = value

      if result[index].length < 3
	expected_stripped = Mail::Header.strip_field_name(expected_header)
      end

      assert_equal(header[index], got_header)
      assert_equal(Mail::Header.strip_field_name(header[index]),
		   expected_stripped,
		   "Stripped result #{index} is wrong")

      assert_equal(expected_tag, got_tag,
		   "field #{index} has incorrect name, " +
		   "expected #{expected_tag.inspect} got " +
		   "#{got_tag.inspect}")
      assert_equal(expected_header, got_header,
		   "field #{index} has incorrect line, " +
		   "expected #{expected_header.inspect} got " +
		   "#{got_header.inspect}")
      assert_equal(expected_stripped,
		   Mail::Header.strip_field_name(got_header))
      assert_equal(header[expected_tag], expected_header)
      assert_equal(expected_stripped, header.get(got_tag))
    }
    assert_equal(index + 1, result.length,
	   "result has too few elements (#{index} < #{result.length})")
  end

  # Read a header from a file and compare against desired results.
  # 'file' is just a filename, 'result' should be as in compare_header
  # (above)
  def read_header_and_compare(string, result)
    tf = Tempfile.new("headers", scratch_dir)
    tf.write(string)
    tf.flush
    tf.seek(0, IO::SEEK_SET)

    # Here we create an object that only has the API of Object + the
    # each_line method.  This way, we can be sure that the
    # Mail::Header object uses only each_line to access the data.
    proxy = Object.new
    proxy.instance_eval {
      @file = tf
    }
    def proxy.each_line
      while line = @file.gets
	yield line
      end
    end

    h = Mail::Header.new(proxy)
    
    tf.close(true)
    compare_header(h, result)
  end
  
  def test_AREF()
    h = Mail::Header.new
    h.add('first', 'this is the first line')
    e = assert_exception(TypeError) {
      h[Object.new]
    }
    assert_kind_of(Exception, e)
    assert_match(/wanted.*String, got.*Object/, e.message)

    e = assert_exception(TypeError) {
      h[[2,3,4]]
    }
    assert_kind_of(Exception, e)
    assert_match(/wanted.*String, got.*Array/, e.message)

    h = Mail::Header.new
    h.add('duplicate', 'this is the first of two')
    h.add('duplicate', 'this is the second of two')
    assert_equal("duplicate: this is the first of two\n", h['duplicate'])
    assert_equal("this is the first of two\n", h.get('duplicate'))

    assert_equal("duplicate: this is the first of two\n", h[-2])
    assert_equal("duplicate: this is the second of two\n", h[-1])
    assert_equal(nil, h[-3])
    assert_equal(nil, h[2])
  end
  

  def test_basic_headers()
    expected = [
      [ 'from', 'From: test@example.com' + "\n", "test@example.com\n" ]
    ]
    data = <<EOF
From: test@example.com

EOF
    read_header_and_compare(data, expected)

    expected = [
      [ 'from', "From: test@example.com\n", "test@example.com\n" ],
      [ 'to', "To: someguy@example.com\n", "someguy@example.com\n" ],
    ]
    data = <<EOF
From: test@example.com
To: someguy@example.com

EOF
    read_header_and_compare(data, expected)

    expected = [
      [ 'from', "frOm: test@example.com\n", "test@example.com\n" ],
      [ 'to', "tO: someguy@example.com\n", "someguy@example.com\n" ],
      [ 'rtfm-url-helper', "rTFm-uRL-helper: http://www.faqs.org\n",
	"http://www.faqs.org\n" ]
    ]
    data = <<EOF
frOm: test@example.com
tO: someguy@example.com
rTFm-uRL-helper: http://www.faqs.org

EOF
    read_header_and_compare(data, expected)

    expected = [
      [ 'from', "frOm: test@example.com\n", "test@example.com\n" ],
      [ 'to', "tO: someguy@example.com,\n someotherguy@example.com\n",
	"someguy@example.com,\n someotherguy@example.com\n" ],
      [ 'rtfm-url-helper', "rTFm-uRL-helper: http://www.faqs.org\n",
	"http://www.faqs.org\n" ]
    ]
    data = <<EOF
frOm: test@example.com
tO: someguy@example.com,
 someotherguy@example.com
rTFm-uRL-helper: http://www.faqs.org

EOF
    read_header_and_compare(data, expected)

    expected = [
      [ 'from', "frOm: test@example.com\n", "test@example.com\n" ],
      [ 'to', "tO: someguy@example.com,\n  someotherguy@example.com,\n" +
	"  \n  thirdguy@example.com\n",
	"someguy@example.com,\n  someotherguy@example.com,\n" +
	"  \n  thirdguy@example.com\n"],
      [ 'rtfm-url-helper', "rTFm-uRL-helper: http://www.faqs.org\n",
	"http://www.faqs.org\n" ]
    ]
    data = <<EOF
frOm: test@example.com
tO: someguy@example.com,
  someotherguy@example.com,
  
  thirdguy@example.com
rTFm-uRL-helper: http://www.faqs.org

EOF
    read_header_and_compare(data, expected)    
  end

  def test_bogus_headers()
    expected = [
      [ 'from', 'From: test@example.test' + "\n", "test@example.test\n" ]
    ]
    data = <<EOF
From: test@example.test
"this is not a real header"

EOF
    read_header_and_compare(data, expected)

    expected = [
      [ 'from', 'From: test@example.com' + "\n", "test@example.com\n" ],
      [ 'subject', 'Subject: a subject' + "\n", "a subject\n" ]
    ]
    data = <<EOF
From: test@example.com
"this is not a real header"
Subject: a subject

EOF
    read_header_and_compare(data, expected)

    expected = [
      [ 'from', 'From: test@example.com' + "\n", "test@example.com\n" ],
      [ 'subject', 'Subject: a subject' + "\n", "a subject\n" ]
    ]
    data = <<EOF
From: test@example.com
"this is not a real header"
    also not a real header
Subject: a subject

EOF
    read_header_and_compare(data, expected)
  end

  def test_add()
    h = Mail::Header.new
    h.add('first', 'this is the first line')
    assert_equal("first: this is the first line\n", h['first:'],
		 "fetch of h['first:'] failed")
    assert_equal("first: this is the first line\n", h['First'],
		 "fetch of h['First'] failed")
    h.add('second:', 'this is the second line')
    assert_equal("second: this is the second line\n", h['SeCoND:'],
		 "basic add failed")
    h.add('third  :', "this is the third line\n")
    assert_equal("third: this is the third line\n", h['third'],
		 "basic add failed")
    
    expected = [
      [ 'first', "first: this is the first line\n",
	"this is the first line\n" ],
      [ 'second', "second: this is the second line\n",
	"this is the second line\n" ],
      [ 'third', "third: this is the third line\n",
	"this is the third line\n" ]
    ]
    compare_header(h, expected)

    # text field name (tag) extraction from the line
    h.add(nil, "Fourth: this is the fourth line")
    expected.push(['fourth', "Fourth: this is the fourth line\n",
		  "this is the fourth line\n"])
    compare_header(h, expected)

    # insert in the middle
    h.add(nil, "just-after-first: this is just after the first", 1)
    expected[1,0] = [
      ['just-after-first',
	"just-after-first: this is just after the first\n",
	"this is just after the first\n" ]
    ]
    compare_header(h, expected)

    # insert at the very beginning
    h.add(nil, "new-first: this the new first", 0)
    expected.unshift(['new-first', "new-first: this the new first\n",
		       "this the new first\n"])
    compare_header(h, expected)

    # lame way to append
    h.add(nil, "last: this is the last header", 999)
    expected.push(['last', "last: this is the last header\n",
		  "this is the last header\n"])
    compare_header(h, expected)

    # append a folded line
    h.add(nil, "tO: someguy@example.com,\n someotherguy@example.com\n")
    expected.push(['to',
		    "tO: someguy@example.com,\n someotherguy@example.com\n",
		    "someguy@example.com,\n someotherguy@example.com\n"])
    compare_header(h, expected)

    # APPEND an invalid line
    assert_exception(ArgumentError, "failed to detect invalid line") {
      h.add(nil,
	    "invalid: someguy@example.com,\nsomeotherguy@example.com\n")
    }
    compare_header(h, expected)
  end

  def verify_match(header, field_name, regexp, expected_result)
    h = header.match(field_name, regexp)
    assert_kind_of(Mail::Header, h)
    assert_equal(h.length != 0, header.match?(field_name, regexp))
    if h.length == 0
      assert_equal(nil, expected_result)
    else
      assert_not_nil(expected_result)
      compare_header(h, expected_result)
    end
  end

  def test_match
    header = new_header

    # First verify argument type checking
    bad_calls = [
      [ "this_is_okay", "this_is_bad1", ArgumentError, /this_is_bad1/ ],
      [ /this_is_bad2/, /this_is_okay/, ArgumentError, /this_is_bad2/ ],
      [ nil, "this_is_bad3", ArgumentError, /this_is_bad3/ ]
    ]
    bad_calls.each {|field_name, regexp, exception, exception_match|
      e = assert_exception(exception) {
	header.match(field_name, regexp)
      }
      assert_match(exception_match, e.message)
      e = assert_exception(exception) {
	header.match?(field_name, regexp)
      }
      assert_match(exception_match, e.message)
    }

    verify_match(header, nil, /this will not match anything/, nil)
    verify_match(header, "to", /./,
		 [ [ 'to', "To: bob@example.net\n" ] ])
    verify_match(header, "tO", /./,
		 [ [ 'to', "To: bob@example.net\n" ] ])
    verify_match(header, "To", /./,
		 [ [ 'to', "To: bob@example.net\n" ] ])
    verify_match(header, "^to", /./, nil)
    verify_match(header, nil, /^(to|cc|resent-to):.*/, nil)
    verify_match(header, nil, /^(to|cc|resent-to):.*/i,
		 [ [ 'to', "To: bob@example.net\n" ],
		   [ 'cc', "Cc: sammy@example.com\n" ],
		   [ 'resent-to',
		     "Resent-To: president@example.com\n"] ])
  end

end
