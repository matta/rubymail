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
require 'rmail/parser/normalizeeolreader'

class TC_NormalizeEOLReader < TestBase

  def test_read_chunk__simple
    reader = RMail::Parser::NormalizeEOLReader.new("a")
    assert_equal("a", reader.read)
  end

  def test_read_chunk__with_newlines
    test_string = "abcdefghijklmnop\nqrstuvwxyz\n".freeze
    string_vary_eol(test_string) { |string|
      1.upto(string.length + 1) { |chunk_size|
        string_as_file(string) { |file|
          reader = RMail::Parser::NormalizeEOLReader.new(file)
          reader.chunk_size = chunk_size

          accum = ''
          while chunk = reader.read
            assert_no_match(/\r\z/, chunk, "Carriage return trails chunk " +
                            "for chunk size #{chunk_size}.")
            accum << chunk
          end

          assert_equal(string.gsub(/\r\n/, "\n"), accum,
                       "Assembled string not equal to " +
                       "original for chunk size #{chunk_size}.")
        }
      }
    }
  end
end
