#!/usr/bin/env ruby
=begin
   Copyright (C) 2001, 2002 Matt Armstrong.  All rights reserved.

   Permission is granted for use, copying, modification, distribution,
   and distribution of modified versions of this work as long as the
   above copyright notice is included.
=end

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
    assert_kind_of(Mail::Header, message.header)
    assert_kind_of(Enumerable, message.header,
		    "Mail::Message.body should be an Enumerable")
  end

  def test_initialize

    # Make sure an empty message actually is empty
    message = Mail::Message.new
    verify_message_interface(message)
    assert_equal(message.header.length, 0)
    assert_nil(message.body)
  end

  def test_to_s
    m = Mail::Message.new
    m.header['To'] = 'bob@example.net'
    m.header['From'] = 'sam@example.com'
    m.header['Subject'] = 'hi bob'
    m.body = <<EOF
Just wanted to say Hi!
EOF

    desired = <<EOF
To: bob@example.net
From: sam@example.com
Subject: hi bob

Just wanted to say Hi!
EOF
    assert_equal(desired, m.to_s)
  end

end
