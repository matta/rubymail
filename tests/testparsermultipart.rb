#!/usr/bin/env ruby
#--
#   Copyright (C) 2002 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

require 'tests/testbase'
require 'mail/parser/multipart'

class TestMailParserMultipart < TestBase

  def test_all
    data_as_file('parser.multipart.simple') { |f|
      p = Mail::Parser::Multipart.new(f, "X")

      assert(p.preamble?); assert(!p.epilogue?)
      assert_equal("1 Preamble1\n", p.gets)
      assert(p.preamble?); assert(!p.epilogue?)
      assert_equal("2 Premable2\n", p.gets)
      assert(p.preamble?); assert(!p.epilogue?)
      assert_nil(p.gets);
      assert(p.preamble?); assert(!p.epilogue?)
      assert_nil(p.gets)
      assert(p.preamble?); assert(!p.epilogue?)

      assert(p.next_part)
      assert(!p.preamble?); assert(!p.epilogue?)

      assert_equal("3 Part1 first\n", p.gets)
      assert(!p.preamble?); assert(!p.epilogue?)
      assert_equal("4 Part1 second\n", p.gets)
      assert(!p.preamble?); assert(!p.epilogue?)
      assert_nil(p.gets)
      assert(!p.preamble?); assert(!p.epilogue?)
      assert_nil(p.gets)
      assert(!p.preamble?); assert(!p.epilogue?)

      assert(p.next_part)
      assert(!p.preamble?); assert(!p.epilogue?)

      assert_equal("5 Part2 first\n", p.gets)
      assert(!p.preamble?); assert(!p.epilogue?)
      assert_equal("6 Part2 second\n", p.gets)
      assert(!p.preamble?); assert(!p.epilogue?)
      assert_equal("--Y\n", p.gets)
      assert(!p.preamble?); assert(!p.epilogue?)
      assert_equal("7 This is in Y\n", p.gets)
      assert(!p.preamble?); assert(!p.epilogue?)
      assert_equal("--Y--\n", p.gets)
      assert(!p.preamble?); assert(!p.epilogue?)
      assert_equal("8 Y epilogue.\n", p.gets)
      assert(!p.preamble?); assert(!p.epilogue?)
      assert_nil(p.gets)
      assert(!p.preamble?); assert(!p.epilogue?)
      assert_nil(p.gets)
      assert(!p.preamble?); assert(!p.epilogue?)

      assert(p.next_part)
      assert(!p.preamble?); assert(!p.epilogue?)

      assert_equal("9 Part3 first\n", p.gets)
      assert(!p.preamble?); assert(!p.epilogue?)
      assert_equal("10 Part3 second\n", p.gets)
      assert(!p.preamble?); assert(!p.epilogue?)
      assert_nil(p.gets)
      assert(!p.preamble?); assert(!p.epilogue?)
      assert_nil(p.gets)
      assert(!p.preamble?); assert(!p.epilogue?)

      assert(p.next_part)
      assert(!p.preamble?); assert(p.epilogue?)

      assert_equal("11 This is the final epilogue.\n", p.gets)
      assert(!p.preamble?); assert(p.epilogue?)
      assert_nil(p.gets)
      assert(!p.preamble?); assert(p.epilogue?)
      assert_nil(p.gets)
      assert(!p.preamble?); assert(p.epilogue?)

      assert(!p.next_part)
      assert(!p.preamble?); assert(p.epilogue?)
    }
  end

  def test_s_new
    data_as_file('parser.multipart.simple') { |f|
      p = Mail::Parser::Multipart.new(f, "foo")
      assert_kind_of(Mail::Parser::Multipart, p)
    }
  end

end

