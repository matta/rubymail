#!/usr/bin/env ruby
#
#   Copyright (c) 2001 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

require 'mail/message'
require 'tests/testbase'

class TestMailMessage < TestBase

  def setup
    super

    @the_mail_file = File.join(scratch_dir, "mail_file")

    @the_mail = %q{From: somedude@example.com
To: someotherdude@example.com
Subject: this is some mail

First body line.

Second body line.
}

    File.open(@the_mail_file, "w") { |file|
      file.print(@the_mail)
    }

    # Test reading in a mail file that has a bad header.  This makes
    # sure we consider the message header to be everything up to the
    # first blank line.
    @the_mail_file_2 = File.join(scratch_dir, "mail_file_2")
    @the_mail_2 = %q{From: somedude@example.com
To: someotherdude@example.com
this is not a valid header
Subject: this is some mail

First body line

Second body line
}
    File.open(@the_mail_file_2, "w") { |file|
      file.print(@the_mail_2)
    }
  end

  def verify_message_interface(message)
    assert_not_nil(message)
    assert_kind_of(Mail::Message, message)
    assert_not_nil(message.header)
    assert_not_nil(message.body)
    assert_kind_of(Mail::Header, message.header)
    assert_kind_of(Enumerable, message.header, 
		    "Mail::Message.body should be an Enumerable")
    assert_kind_of(Enumerable, message.body, 
		    "Mail::Message.body should be an Enumerable")
    assert_respond_to(:length, message.body)
  end

  def test_initialize

    # Make sure an empty message actually is empty
    message = Mail::Message.new(nil)
    verify_message_interface(message)
    assert_equal(message.body.length, 0)
  end

  def test_read
    message = nil
    File.open(@the_mail_file, "r") { |file|
      # Here we create an object that only has the API of Object + the
      # each_line method.  This way, we can be sure that the
      # Mail::Header object uses only each_line to access the data.
      proxy = Object.new
      proxy.instance_eval {
	@file = file
      }
      def proxy.each_line
	while line = @file.gets
	  yield line
	end
      end
      message = Mail::Message.new(proxy)
    }

    verify_message_interface(message)
    assert_equal(3, message.body.length)
    assert_match(/somedude@example\.com/, message.header['from'])
    assert_match(/someotherdude@example\.com/, message.header['to'])
    assert_equal("Subject: this is some mail\n", message.header['subject'])
    assert_equal("First body line.\n", message.body[0])
    assert_equal("\n", message.body[1])
    assert_equal("Second body line.\n", message.body[2])
    assert_nil(message.body[3])
    assert_equal("Second body line.\n", message.body[-1])
    assert_equal("\n", message.body[-2])
    assert_equal("First body line.\n", message.body[-3])
    assert_nil(message.body[-4])
    assert_nil(message.body[-1000])
    assert_nil(message.body[1000])
  end

  def test_read_invalid
    message = nil
    File.open(@the_mail_file_2, "r") { |file|
      message = Mail::Message.new(file)
    }
    verify_message_interface(message)
    assert_equal(3, message.body.length)
    assert_match(/somedude@example\.com/, message.header['from'])
    assert_match(/someotherdude@example\.com/, message.header['to'])
    assert_equal("Subject: this is some mail\n", message.header['subject'])
    assert_equal("First body line\n", message.body[0])
    assert_equal("\n", message.body[1])
    assert_equal("Second body line\n", message.body[2])
    assert_nil(message.body[3])
    assert_equal("Second body line\n", message.body[-1])
    assert_equal("\n", message.body[-2])
    assert_equal("First body line\n", message.body[-3])
    assert_nil(message.body[-4])
    assert_nil(message.body[-1000])
    assert_nil(message.body[1000])

    # FIXME: write the message out and verify it is the same as the
    # first message
  end

  def test_to_s
    message = nil
    File.open(@the_mail_file, "r") { |file|
      message = Mail::Message.new(file)
    }
    verify_message_interface(message)

    assert_equal(@the_mail, message.to_s)
  end

end
