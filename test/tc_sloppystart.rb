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
require 'rmail/parser/sloppystart'

class TC_SloppyStart < TestBase
  def test_super_simple
    reader = RMail::Parser::SloppyStartReader.new("a")
    assert_equal("a", reader.read)
  end

  def test_less_trivial
    test_string = "abcdefj\nhijklmnop\nqrstuvwxyz".freeze
    1.upto(test_string.length + 1) { |chunk_size|
      string_as_file(test_string) { |file|
        reader = RMail::Parser::SloppyStartReader.new(file)
        reader.chunk_size = chunk_size

        accum = ''
        while chunk = reader.read
          accum << chunk
        end

        assert_equal(test_string, accum)
      }
    }
  end

  def test_with_newline_slop
    test_string = "\n\n\nabcdefj\nhijklmnop\nqrstuvwxyz".freeze
    expected_string = "abcdefj\nhijklmnop\nqrstuvwxyz".freeze
    1.upto(test_string.length + 1) { |chunk_size|
      string_as_file(test_string) { |file|
        reader = RMail::Parser::SloppyStartReader.new(file)
        reader.chunk_size = chunk_size

        accum = ''
        while chunk = reader.read
          accum << chunk
        end

        assert_equal(expected_string, accum)
      }
    }
  end

end
