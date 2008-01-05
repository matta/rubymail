#!/usr/bin/env ruby
#--
#   Copyright (c) 2004 Matt Armstrong.  All rights reserved.
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
require 'rmail/parser/accumulatereader'

class TC_RMailParserAccumulateReader < TestBase

  def test_substring
    reader = RMail::Parser::AccumulateReader.new("hi mom")
    assert_equal("hi mom", reader.read(nil))
    assert_kind_of(RMail::Substring, reader.substring(1,4))
    assert_equal("i mo", reader.substring(1,4).to_str)
  end

  def test_pos
    require 'stringio'
    io = StringIO.new("hi mom")
    reader = RMail::Parser::AccumulateReader.new(io)

    # when the PushbackReader has a real IO behind it, the read size
    # hints are honored more closely.
    assert_equal(0, reader.pos)
    assert_equal("h", reader.read(1))
    assert_equal(1, reader.pos)
    assert_equal("i ", reader.read(2))
    assert_equal(3, reader.pos)
    assert_equal("hi ", reader.accumulated.to_str)
    reader.pushback(" ")
    assert_equal(2, reader.pos)
    assert_equal("hi", reader.accumulated.to_str)
    assert_equal(" mom", reader.read(nil))
    assert_equal(6, reader.pos)
    assert_equal("hi mom", reader.accumulated.to_str)
  end

  def test_pushback
    reader = RMail::Parser::AccumulateReader.new("hi mom")
    assert_raise(RMail::Parser::PushbackReader::DuplicatePushbackError) {
      reader.pushback("hi bob")
    }
    assert_equal("", reader.accumulated.to_str)
    chunk = reader.read
    assert_equal(chunk, reader.accumulated.to_str)

    pushback = chunk[-1..-1]
    reader.pushback(pushback)
    assert_equal(chunk[0..-2], reader.accumulated.to_str)
    assert_equal(pushback, reader.read)
    assert_equal(chunk, reader.accumulated.to_str)
  end

  def test_read_chunk
    require 'stringio'
    io = StringIO.new("hi mom")
    reader = RMail::Parser::AccumulateReader.new(io)

    # when the PushbackReader has a real IO behind it, the read size
    # hints are honored more closely.
    assert_equal("h", reader.read(1))
    assert_equal("i ", reader.read(2))
    assert_equal("hi ", reader.accumulated.to_str)
    reader.pushback(" ")
    assert_equal("hi", reader.accumulated.to_str)
    assert_equal(" mom", reader.read(nil))
    assert_equal("hi mom", reader.accumulated.to_str)
  end

end
