#!/usr/bin/env ruby
#
#   Copyright (c) 2001 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

require 'tests/testbase'
require 'mail/deliver'
require 'tempfile'

class TestMailDeliver < TestBase
  include Mail::Deliver

  # Validates an mbox style mailbox and returns the number of messages
  # it contains.
  def validate_mbox(filename, sentinel)
    mailcount = 0
    line_count = 1
    message_line_count = 0
    body_line_count = -1
    prevline = nil
    sentinel_match = true
    IO.foreach(filename) { |line|
      assert(line[-1] == ?\n, 
	     "Line #{line_count} #{line.inspect} does not end in a newline")
      
      if (line_count == 1)
	assert_match(line, /^From /, 'first line in file is not "From "')
      end

      if ((line_count == 1 || prevline == "\n") && line =~ /^From /)
	mailcount += 1
	message_line_count = 0
	assert(prevline.nil? || body_line_count >= 0, "No body found")
	body_line_count = -1
	unless sentinel.nil?
	  assert(sentinel_match, "Mail did not contain sentinel " +
		 sentinel.inspect)
	  sentinel_match = false
	end
      end

      if body_line_count < 0 && line =~ /^$/
	body_line_count = 0
      end

      unless sentinel.nil?
	if line =~ sentinel
	  sentinel_match = true
	end
      end

      if (message_line_count == 1)
	assert_match(line, /^\S+:/,
		     "Message at line #{line_count} does not begin " +
		     "with headers")
      end

      prevline = line
      line_count += 1
      message_line_count += 1
      body_line_count += 1 if body_line_count >= 0
    }
    assert(sentinel_match, "Mail did not contain sentinel " +
	   sentinel.inspect) unless sentinel.nil?
    return mailcount
  end

  def test_deliver_mbox_no_each_method()
    mailbox = File.join(scratch_dir, "mbox.no_each_method")

    assert(!test(?e, mailbox))
    e = assert_exception(NO_METHOD_ERROR) {
      deliver_mbox(mailbox, nil)
    }
    assert_not_nil(e)
    assert_match(/undefined method `each'/, e.message)

    assert(test(?f, mailbox))
    assert(test(?z, mailbox))
    assert_equal(0, validate_mbox(mailbox, nil))
    e = assert_exception(NO_METHOD_ERROR) {
      deliver_mbox(mailbox, Object.new)
    }
    assert_not_nil(e)
    assert(test(?f, mailbox))
    assert(test(?z, mailbox))
    assert_equal(0, validate_mbox(mailbox, nil))
    assert_match(/undefined method `each'/, e.message)
  end

  def test_deliver_mbox_string_with_from()
    mailbox = File.join(scratch_dir, "mbox.string_with_from")
    assert(!test(?e, mailbox))
    string_message =
      "From baz@bango  Fri Nov  9 23:00:43 2001\nX-foo: foo\n\nfoo"
    deliver_mbox(mailbox, string_message)
    assert(test(?f, mailbox))
    assert_equal(string_message.length + 2, test(?s, mailbox))
    assert_equal(1, validate_mbox(mailbox, /^foo$/))
  end

  def test_deliver_mbox_string_without_from()
    mailbox = File.join(scratch_dir, "mbox.string_without_from")
    assert(!test(?e, mailbox))
    string_message = "X-foo: foo\n\nfoo"
    deliver_mbox(mailbox, string_message)
    assert(test(?f, mailbox))
    assert_equal("From foo@bar  Fri Nov  9 23:00:43 2001\n".length +
		 string_message.length + 2, test(?s, mailbox))
    assert_equal(1, validate_mbox(mailbox, /^foo$/))
  end

  def test_deliver_mbox_array_with_from()
    mailbox = File.join(scratch_dir, "mbox.array_with_from")
    assert(!test(?e, mailbox))
    array_message = [
      'From baz@bango  Fro Nov  9 23:00:43 2001',
      'X-foo: foo',
      '',
      'foo' ]
    deliver_mbox(mailbox, array_message)
    assert(test(?f, mailbox))
    assert_equal(array_message.join("\n").length + 2, test(?s, mailbox))
    assert_equal(1, validate_mbox(mailbox, /^foo$/))
  end

  def test_deliver_mbox_array_without_from()
    mailbox = File.join(scratch_dir, "mbox.array_without_from")
    assert(!test(?e, mailbox))
    array_message = [
      'X-foo: foo',
      '',
      'foo' ]
    deliver_mbox(mailbox, array_message)
    assert(test(?f, mailbox))
    assert_equal("From baz@bar  Fri Nov  9 23:00:43 2001\n".length + 
		 array_message.join("\n").length + 2, test(?s, mailbox))
    assert_equal(1, validate_mbox(mailbox, /^foo$/))
  end
  
  def test_deliver_mbox_complex()
    mailbox = File.join(scratch_dir, "mbox.complex")
    obj = Object.new

    def obj.each
      yield "x-header: header value"
      yield ""
      yield "complex body text"
      yield "complex body text again"
      yield "From is escaped"
      yield "From. not escaped"
    end
    def obj.mbox_from
      "From complex@object  Fri Nov  9 23:00:43 2001"
    end

    assert(!test(?e, mailbox))
    deliver_mbox(mailbox, obj)
    deliver_mbox(mailbox, obj)
    assert(test(?f, mailbox))
    assert_equal(296, test(?s, mailbox))
    assert_equal(2, validate_mbox(mailbox, /^complex body text again$/))

    File.open(mailbox) {|f|
      # make sure leading body "From " lines are escaped
      f.grep(/is escaped/).each {|escaped|
	assert_match(/^>From /, escaped)
      }
      # but not all "From" lines are escaped
      f.grep(/.?From[^ ]/).each {|escaped|
	assert_not_match(/^>From /, escaped)
      }
      # make sure the From_ headers are what obj.get_mbox_from returns
      f.grep(/From /).each {|from|
	assert_equal(obj.mbox_from + "\n", from)
      }
    }
  end

  def test_deliver_pipe_no_each_method()
    output = File.join(scratch_dir, "pipe.no_each_method")
    command = "/bin/cat > #{output}"

    assert_equal(false, test(?e, output))
    e = assert_exception(NO_METHOD_ERROR) {
      deliver_pipe(command, nil)
    }
    assert_not_nil(e)
    assert_match(/undefined method `each'/, e.message)
    assert_equal(true, test(?e, output))
    assert_equal(true, test(?z, output))

    e = assert_exception(NO_METHOD_ERROR) {
      deliver_pipe(command, Object.new)
    }
    assert_not_nil(e)
    assert_match(/undefined method `each'/, e.message)
    assert_equal(true, test(?e, output))
    assert_equal(true, test(?z, output))
  end

  def test_deliver_pipe_simple()
    output = File.join(scratch_dir, "pipe.simple")
    command = "/bin/cat > #{output}"

    message1 = "This is message one."
    assert_equal(false, test(?e, output))
    deliver_pipe(command, message1)
    got = File.open(output).readlines().join('')
    assert_equal(message1 + "\n", got)

    message2 = %q{This is message two.
It has some newlines in it.
And it even ends with one.
}
    deliver_pipe(command, message2)
    got = File.open(output).readlines().join('')
    assert_equal(message2, got)

    message3 = [ "Line 1", "Line 2", "", "Line 3" ]
    deliver_pipe(command, message3)
    got = File.open(output).readlines().join('')
    assert_equal(message3.join("\n") + "\n", got)
  end

  def test_deliver_pipe_failed()
    command = "/bin/sh -c 'exit 7'"
    deliver_pipe(command, "irrelevant message")
    assert_equal(7 << 8, $?)

    # now attempt to generate an EPIPE pipe error
    long_message = []
    0.upto(5000) {
      long_message.push("This is a line of text")
    }
    deliver_pipe(command, long_message)
    assert_equal(7 << 8, $?)
  end
  
end
