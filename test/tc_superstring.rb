#!/usr/bin/env ruby
#--
#   Copyright (c) 2004, 2005 Matt Armstrong.  All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The name of the author may not be used to endorse or promote products
#    derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN
# NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
# TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

require 'test/testbase'
require 'rmail/superstring'

class TC_Substring < TestBase
  def help_test_to_string(method)
    ss = RMail::Substring.new("abcdefg", 1, 2)
    assert_kind_of(String, ss.send(method))
    assert_equal("bc", ss.send(method))
    assert_equal("bc", ss)
  end

  def test_to_s
    help_test_to_string(:to_s)
  end

  def test_to_str
    help_test_to_string(:to_str)
  end

  def help_test_each_line(method)
    ss = RMail::Substring.new("ab\ncd\nef", 1, 6)

    assert_kind_of(String, ss.to_str)
    assert_equal("b\ncd\ne", ss.to_str)

    expected = []
    ss.to_str.each_line do |line|
      expected << line
    end
    assert_equal(["b\n", "cd\n", "e"], expected,
                 "did not get expected expected array, heh!")

    actual = []
    ss.send(method) do |line|
      actual << line
    end
    assert_equal(expected, actual,
                 "Substring mismatch.")
  end

  def test_each
    help_test_each_line(:each)
  end

  def test_each_line
    help_test_each_line(:each_line)
  end

  def test_length
    ss = RMail::Substring.new("abcdefg", 1, 2)
    assert_equal(2, ss.length)
  end

  def test_EQUAL # '=='
    ss = RMail::Substring.new("abcdefg", 1, 2)
    assert_equal(ss, "bc")
  end

  def test_AREF # '[]'
    ss = RMail::Substring.new("abcdefg", 1, 3)
    assert_equal("bcd", ss)
    assert_equal("b", ss[0].chr)
    assert_equal("d", ss[-1].chr)
  end

end


class TC_Superstring < Test::Unit::TestCase

  def test_LSHIFT # '<<'
    superstr = RMail::Superstring.new
    superstr << 'a'
    assert_equal(1, superstr.length)
    superstr << 'b'
    assert_equal(2, superstr.length)
  end

  def test_slice
    superstr = RMail::Superstring.new
    superstr << '0123456789'
    assert_kind_of(String, superstr.slice(0, 2))
    assert_equal("23", superstr.slice(2, 2))
  end

  def test_freeze
    superstr = RMail::Superstring.new
    superstr << '0123456789'
    superstr.freeze
    assert_kind_of(String, superstr.slice(0, 3))
    assert_equal("2345", superstr.slice(2, 4))
    e = assert_raise(RuntimeError, TypeError) do
      superstr << 'burp'
    end
    assert_equal("can't modify frozen string", e.message)
    assert_raise(ArgumentError) do
      superstr.truncate(3)
    end
  end

  def test_inspect
    # not tested
  end

  def test_length
    superstr = RMail::Superstring.new
    superstr << 'a'
    assert_equal(1, superstr.length)
    superstr << 'b'
    assert_equal(2, superstr.length)
  end

  def test_protect
    superstr = RMail::Superstring.new
    superstr << '012345679'

    superstr.protect(0)
    assert_nothing_raised do
      superstr.truncate(0)
    end
    superstr << '012345679'

    superstr.protect(1)
    assert_raise(ArgumentError) do
      superstr.truncate(0)
    end
    assert_nothing_raised do
      superstr.truncate(1)
    end

    assert_raise(ArgumentError) do
      superstr.protect(9)
    end

    assert_equal(1, superstr.length)
    superstr << '123456789'

    assert_raise(ArgumentError) do
      superstr.truncate(0)
    end

    superstr.protect(9)
    assert_nothing_raised do
      superstr.truncate(9)
    end

    assert_raise(ArgumentError) do
      superstr.protect(10)
    end
  end

  def test_substring
    superstr = RMail::Superstring.new
    superstr << '0123456789'

    substr = superstr.substring(2, 8)
    assert_equal("23456789", substr.to_s)

    assert_raise(ArgumentError) do
      substr = superstr.substring(2, 9)
    end
    assert_raise(ArgumentError) do
      substr = superstr.substring(-1, 9)
    end
    assert_raise(ArgumentError) do
      substr = superstr.substring(-1, 1)
    end
    assert_raise(ArgumentError) do
      substr = superstr.substring(5, -2)
    end
  end

  def test_truncate
    superstr = RMail::Superstring.new
    superstr << '0123456789'

    substr = superstr.substring(0, 10)
    superstr.truncate(5)

    begin
      assert_nothing_raised do
        superstr.substring(0, 5)
      end
      ss = superstr.substring(0, 5)
      assert_equal("01234", ss.to_s)
    end

    assert_raise(ArgumentError) do
      substr = superstr.substring(0, 6)
    end
  end

  def test_AREF # '[]'
    # tested through the Substring class
  end

end
