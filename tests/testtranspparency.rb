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
require 'mail/serialize'

class TestMailTransparency < TestBase
  def do_file(file)
    message1 = data_as_file(file) { |f|
      Mail::Parser.new.parse(f)
    }
    scratch_base = "temp-" + file.gsub(/[^\w]/, '-')
    message2 = File.open(scratch_filename(scratch_base), "w+") { |f|
      Mail::Serialize.new(f).serialize(message1)
      f.seek(0)
      Mail::Parser.new.parse(f)
    }
    if message1 != message2
      pp message1
      pp message2
    end
    assert_equal(message1, message2,
                 "#{file} didn't come out like it went in.")
  end

  # Test that all our various input files get formatted on output the
  # same way they came in.
  def test_mail_transparency
    do_file('parser.simple-mime')
    do_file('parser.rfc822')
    do_file('parser.nested-multipart')
    1.upto(6) do |i|
      do_file("transparency/message.#{i}")
    end
  end
end
