#!/usr/bin/env ruby
=begin
   Copyright (C) 2002 Matt Armstrong.  All rights reserved.

   Permission is granted for use, copying, modification,
   distribution, and distribution of modified versions of this work
   as long as the above copyright notice is included.
=end

require 'tests/testbase'
require 'mail/parser'

class TestMail__Parser < TestBase

  def test_parse
    p = Mail::Parser.new
    assert_instance_of(Mail::Parser, p)

    string_msg = <<-EOF
    From matt@lickey.com  Mon Dec 24 00:00:06 2001
    From:    matt@example.net
    To:   matt@example.com
    Subject: test message

    message body
    has two lines
    EOF

    m = string_as_file(string_msg) { |f|
      p.parse(f)
    }
    assert_instance_of(Mail::Message, m)
    assert_equal("From matt@lickey.com  Mon Dec 24 00:00:06 2001\n",
                 m.header.mbox_from)
    assert_equal("matt@example.net\n", m.header[0])
    assert_equal("matt@example.net\n", m.header['from'])
    assert_equal("matt@example.com\n", m.header[1])
    assert_equal("matt@example.com\n", m.header['to'])
    assert_equal("test message\n", m.header[2])
    assert_equal("test message\n", m.header['subject'])
    assert_equal("message body\nhas two lines\n", m.body)
  end

  def test_s_new
    p = Mail::Parser.new
    assert_instance_of(Mail::Parser, p)
  end

end
