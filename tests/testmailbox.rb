#!/usr/bin/env ruby
#--
#   Copyright (c) 2002 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

require 'tests/testbase'
require 'rmail/mailbox'

class TestRMailMailbox < TestBase
  def test_parse_mbox_simple
    expected = ["From foo@bar  Wed Nov 27 12:27:32 2002\nmessage1\n",
      "From foo@bar  Wed Nov 27 12:27:36 2002\nmessage2\n",
      "From foo@bar  Wed Nov 27 12:27:40 2002\nmessage3\n"]
    data_as_file("mbox.simple") { |f|
      assert_equal(expected, RMail::Mailbox::parse_mbox(f))
    }
    data_as_file("mbox.simple") { |f|
      messages = []
      RMail::Mailbox::parse_mbox(f) { |m|
        messages << m
      }
      assert_equal(expected, messages)
    }
  end
end
