#!/usr/bin/env ruby
#--
#   Copyright (C) 2002 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

require 'tests/testbase'
require 'mail/parser'

class TestMailTransparency < TestBase
  def do_file(file)
    m = data_as_file(file) { |f|
      Mail::Parser.new.parse(f)
    }
    s = IO::readlines(data_filename(file), nil).first
    assert_equal(s, m.to_s, "#{file} didn't come out like it went in.")
  end

  # Test that all our various input files get formatted on output the
  # same way they came in.
  def test_mail_transparency
    do_file('parser.simple-mime')
    do_file('parser.rfc822')
    do_file('parser.nested-multipart')
    1.upto(5) do |i|
      do_file("transparency/message.#{i}")
    end
  end
end
