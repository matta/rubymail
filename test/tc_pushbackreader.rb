#!/usr/bin/env ruby
#--
#   Copyright (c) 2002, 2004 Matt Armstrong.  All rights reserved.
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
require 'rmail/parser/pushbackreader'

class TC_PushbackReader < TestBase

  def test_pushback
    reader = RMail::Parser::PushbackReader.new("")
    assert_raise(RMail::Parser::PushbackReader::DuplicatePushbackError) {
      reader.pushback("hi bob")
    }
  end

  def test_chunk_size
    parser = RMail::Parser::PushbackReader.new("")
    assert_equal(1024 * 16, parser.chunk_size)
  end

  def test_chunk_size_SET # 'chunk_size='
    parser = RMail::Parser::PushbackReader.new("")
    parser.chunk_size = 4
    assert_equal(4, parser.chunk_size)
  end

  def help_test_eof(reader)
    assert(!reader.eof)
    reader.read(nil)
    assert(reader.eof)
  end

  def test_eof
    help_test_eof(RMail::Parser::PushbackReader.new("hi mom"))
    string_as_file("hi mom", "hi_mom") { |f|
      help_test_eof(RMail::Parser::PushbackReader.new(f))
    }
  end

  def with_reader_io(string)
    string_as_file(string, "reader_for_string") do |f|
      yield RMail::Parser::PushbackReader.new(f)
    end
  end

  def with_reader_string(string)
    yield RMail::Parser::PushbackReader.new(string)
  end

  def with_reader(string)
    with_reader_io(string) do |reader|
      yield reader
    end
    with_reader_string(string) do |reader|
      yield reader
    end
  end

  def test_read
    with_reader("Test String: read(nil)") do |reader|
      assert_equal("Test String: read(nil)", reader.read(nil))
    end
    with_reader_io("Test String: read(5)") do |reader|
      assert_equal("Test ", reader.read(5))
      assert_equal("Strin", reader.read(5))
      assert_equal("g: re", reader.read(5))
      assert_equal("ad(5)", reader.read(5))
      assert(reader.eof)
    end
  end

  def test_read_chunk
    # not tested, #read is implemented in terms of this
  end

  def test_standard_read_chunk
    # not tested, #read_chunk is implemented in terms of this
  end

  def test_pos
    with_reader("YaYa") do |reader|
      assert_equal(0, reader.pos)
      s = reader.read(2)
      assert_equal(s.length, reader.pos)
      reader.pushback(s[-1,1])
      assert_equal(s.length - 1, reader.pos)
    end
    string_as_file("Test String: seek", "seek") { |f|
      f.seek(13)
      assert_equal(13, f.pos)
      reader = RMail::Parser::PushbackReader.new(f)
      assert_equal(f.pos, reader.pos)
      assert_equal(13, reader.pos)

      s = reader.read(2)
      assert_equal(13 + s.length, reader.pos)
      reader.pushback(s[-1,1])
      assert_equal(13 + s.length - 1, reader.pos)
    }
  end

end
