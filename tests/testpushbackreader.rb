#!/usr/bin/env ruby
#--
#   Copyright (c) 2002 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

require 'tests/testbase'
require 'rmail/mailbox/mboxreader'

class TextRMailParserPushbackReader < TestBase

  def test_pushback
    reader = RMail::Parser::PushbackReader.new("")
    assert_exception(RMail::Parser::Error) {
      reader.pushback("hi bob")
    }
  end

end
