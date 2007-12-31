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
require 'rmail/parser'

class TC_StreamParser < TestBase

  class RecordingStreamHandler
    def initialize(history)
      @history = history
    end
    def raw_entity(header, body, whole)
      @history << [ :raw_entity, header.to_str, body.to_str, whole.to_str ]
    end
    def method_missing(symbol, *args)
      @history << [ symbol ].concat(args)
    end
  end

  def test_parse__simple
    string_msg = \
'From matt@rfc20.com  Mon Dec 24 00:00:06 2001
From:    matt@example.net
To:   matt@example.com
Subject: test message

message body
has two lines
'

    string_vary_eol(string_msg) { |s|
      string_as_file(s) { |f|
        RMail::StreamParser.parse(f, RMail::StreamHandler.new)
        f.rewind
        history = []
        RMail::StreamParser.parse(f, RecordingStreamHandler.new(history))
        expected = [
          [:mbox_from, "From matt@rfc20.com  Mon Dec 24 00:00:06 2001"],
          [:header_field, "From:    matt@example.net", "From",
            "matt@example.net"],
          [:header_field, "To:   matt@example.com", "To", "matt@example.com"],
          [:header_field, "Subject: test message", "Subject", "test message"],
          [:body_begin],
          [:body_chunk, "message body\nhas two lines\n"],
          [:body_end],
          [:raw_entity,
            "From matt@rfc20.com  Mon Dec 24 00:00:06 2001\nFrom:    matt@example.net\nTo:   matt@example.com\nSubject: test message\n\n",
            "message body\nhas two lines\n",
            string_msg]
        ]
        assert_equal(expected, history)
      }
    }
  end

  def test_parse__multipart
    string_msg = \
'Content-Type: multipart/mixed; boundary="aa"
MIME-Version: 1.0

preamble
--aa
Header1: hi mom

body1
--aa--
epilogue
'

    string_vary_eol(string_msg) { |s|
      string_as_file(s) { |f|
        RMail::StreamParser.parse(f, RMail::StreamHandler.new)
        f.rewind
        history = []
        RMail::StreamParser.parse(f, RecordingStreamHandler.new(history))
        expected = [
          [:header_field, "Content-Type: multipart/mixed; boundary=\"aa\"",
            "Content-Type", "multipart/mixed; boundary=\"aa\""],
          [:header_field, "MIME-Version: 1.0", "MIME-Version", "1.0"],
          [:multipart_body_begin],
          [:preamble_chunk, "preamble"],
          [:part_begin],
          [:header_field, "Header1: hi mom", "Header1", "hi mom"],
          [:body_begin],
          [:body_chunk, "body1"],
          [:body_end],
          [:raw_entity, "Header1: hi mom\n\n", "body1", "Header1: hi mom\n\nbody1"],
          [:part_end],
          [:epilogue_chunk, "epilogue\n"],
          [:multipart_body_end,  ["\n--aa\n", "\n--aa--\n"], "aa"],
          [:raw_entity,
            "Content-Type: multipart/mixed; boundary=\"aa\"\nMIME-Version: 1.0\n\n",
            "preamble\n--aa\nHeader1: hi mom\n\nbody1\n--aa--\nepilogue\n",
            string_msg
          ]
        ]
        assert_equal(expected, history)
      }
    }
  end

  def test_chunk_size
    parser = RMail::StreamParser.new(nil, nil)
    assert_nil(parser.chunk_size)
  end

  def test_chunk_size_SET # 'chunk_size='
    parser = RMail::StreamParser.new(nil, nil)
    parser.chunk_size = 5
    assert_equal(5, parser.chunk_size)
  end

end
