#!/usr/bin/env ruby
#--
#   Copyright (C) 2002 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

require 'tests/testbase'
require 'rmail/parser'
require 'rmail/serialize'

class TestRMailTransparency < TestBase
  def do_file(file)
    full_name = data_filename(file)
    message1 = data_as_file(file) { |f|
      RMail::Parser.new.parse(f)
    }
    scratch_base = file.gsub(/[^\w]/, '-')
    scratch_name = scratch_filename(scratch_base)
    message2 = File.open(scratch_name, "w+") { |f|
      RMail::Serialize.new(f).serialize(message1)
      f.seek(0)
      RMail::Parser.new.parse(f)
    }
    if message1 != message2
      puts "-" * 70
      pp message1
      puts "-" * 70
      pp message2
      puts "-" * 70
    end
    assert(File.compare(full_name, scratch_name),
           "parse->serialize failure transparency #{file}")
    assert_equal(message1, message2,
                 "parse->serialize->parse transparency failure #{file}")
  end

  # Test that all our various input files get formatted on output the
  # same way they came in.
  def test_transparency_simple_mime
    do_file('parser.simple-mime')
  end
  def test_transparency_rfc822
    do_file('parser.rfc822')
  end
  def test_transparency_nested_multipart
    do_file('parser.nested-multipart')
  end
  def test_transparency_message_01
    do_file("transparency/message.1")
  end
  def test_transparency_message_02
    do_file("transparency/message.2")
  end
  def test_transparency_message_03
    do_file("transparency/message.3")
  end
  def test_transparency_message_04
    do_file("transparency/message.4")
  end
  def test_transparency_message_05
    do_file("transparency/message.5")
  end
  def test_transparency_message_06
    do_file("transparency/message.6")
  end
  def test_transparency_absolute_01
    do_file('transparency/absolute.1')
  end
  def test_transparency_absolute_02
    do_file('transparency/absolute.2')
  end
  def test_transparency_absolute_03
    do_file('transparency/absolute.3')
  end
  def test_transparency_absolute_04
    do_file('transparency/absolute.4')
  end
  def test_transparency_absolute_05
    do_file('transparency/absolute.5')
  end
  def test_transparency_absolute_06
    do_file('transparency/absolute.6')
  end
end
