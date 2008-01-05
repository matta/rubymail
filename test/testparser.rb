#!/usr/bin/env ruby
#--
#   Copyright (C) 2002, 2003, 2004 Matt Armstrong.  All rights reserved.
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

class TestRMailStreamParser < TestBase

  class RecordingStreamHandler
    def initialize(history)
      @history = history
    end
    def method_missing(symbol, *args)
      @history << [ symbol ].concat(args)
    end
  end

  def test_stream_parser_simple
    string_msg = \
'From matt@lickey.com  Mon Dec 24 00:00:06 2001
From:    matt@example.net
To:   matt@example.com
Subject: test message

message body
has two lines
'

    string_as_file(string_msg) { |f|
      RMail::StreamParser.parse(f, RMail::StreamHandler.new)
      f.rewind
      history = []
      RMail::StreamParser.parse(f, RecordingStreamHandler.new(history))
      expected = [
        [:mbox_from, "From matt@lickey.com  Mon Dec 24 00:00:06 2001"],
        [:header_field, "From:    matt@example.net", "From",
          "matt@example.net"],
        [:header_field, "To:   matt@example.com", "To", "matt@example.com"],
        [:header_field, "Subject: test message", "Subject", "test message"],
        [:body_begin],
        [:body_chunk, "message body\nhas two lines\n"],
        [:body_end]]
      assert_equal(expected, history)
    }
  end

  def test_stream_parser_multipart
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

    string_as_file(string_msg) { |f|
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
        [:part_end],
        [:epilogue_chunk, "epilogue\n"],
        [:multipart_body_end,  ["\n--aa\n", "\n--aa--\n"], "aa"]
      ]
      assert_equal(expected, history)
    }
  end

end


class TestRMailParser < TestBase

  def common_test_parse(m)
    assert_instance_of(RMail::Message, m)
    assert_equal("From matt@lickey.com  Mon Dec 24 00:00:06 2001",
                 m.header.mbox_from)
    assert_equal("matt@example.net", m.header[0])
    assert_equal("matt@example.net", m.header['from'])
    assert_equal("matt@example.com", m.header[1])
    assert_equal("matt@example.com", m.header['to'])
    assert_equal("test message", m.header[2])
    assert_equal("test message", m.header['subject'])
    assert_equal("message body\nhas two lines\n", m.body)
  end

  def test_parse
    p = RMail::Parser.new

    string_msg = <<-EOF
From matt@lickey.com  Mon Dec 24 00:00:06 2001
From:    matt@example.net
To:   matt@example.com
Subject: test message

message body
has two lines
    EOF

    m = string_as_file(string_msg) { |f|
      p.parse(f)
    }
    common_test_parse(m)

    m = p.parse(string_msg)
    common_test_parse(m)
  end

  def test_parse_simple_mime
    p = RMail::Parser.new
    m = data_as_file('parser.simple-mime') { |f|
      p.parse(f)
    }

    assert_instance_of(RMail::Message, m)
    assert_equal("Nathaniel Borenstein <nsb@bellcore.com>", m.header[0])
    assert_equal("Nathaniel Borenstein <nsb@bellcore.com>", m.header['from'])
    assert_equal("Ned Freed <ned@innosoft.com>", m.header[1])
    assert_equal("Ned Freed <ned@innosoft.com>", m.header['To'])
    assert_equal("Sun, 21 Mar 1993 23:56:48 -0800 (PST)", m.header[2])
    assert_equal("Sun, 21 Mar 1993 23:56:48 -0800 (PST)",
                 m.header['Date'])
    assert_equal("Sun, 21 Mar 1993 23:56:48 -0800 (PST)",
                 m.header['Date'])
    assert_equal("Sample message", m.header[3])
    assert_equal("Sample message", m.header['Subject'])
    assert_equal("1.0", m.header[4])
    assert_equal("1.0", m.header['MIME-Version'])
    assert_equal("multipart/mixed; boundary=\"simple boundary\"",
                 m.header[5])
    assert_equal("multipart/mixed; boundary=\"simple boundary\"",
                 m.header['Content-Type'])

    # Verify preamble
    assert_equal(%q{This is the preamble.  It is to be ignored, though it
is a handy place for composition agents to include an
explanatory note to non-MIME conformant readers.
},
                 m.preamble)

    # Verify the first part
    assert_equal(%q{This is implicitly typed plain US-ASCII text.
It does NOT end with a linebreak.}, m.part(0).body)
    assert_equal(nil, m.part(0).header['content-type'])

    # Verify the second part
    assert_equal(%q{This is explicitly typed plain US-ASCII text.
It DOES end with a linebreak.
}, m.part(1).body)
    assert_equal("text/plain; charset=us-ascii",
                 m.part(1).header['content-type'])

    # Verify the epilogue
    assert_equal("\nThis is the epilogue.  It is also to be ignored.\n",
                 m.epilogue)
  end

  def test_parse_nested_simple
    m = data_as_file('parser.nested-simple') { |f|
      RMail::Parser.new.parse(f)
    }
    assert_nil(m.preamble)
    assert_nil(m.part(0).preamble)
    assert_equal("", m.part(0).epilogue)
    assert_equal("", m.epilogue)
  end

  def test_parser_nested_simple2
    m = data_as_file('parser.nested-simple2') { |f|
      RMail::Parser.new.parse(f)
    }

    assert_nil(m.preamble)
    assert_nil(m.part(0).preamble)
    assert_equal("", m.part(0).epilogue)
    assert_equal("\n", m.epilogue)
  end

  def test_parser_nested_simple3
    m = data_as_file('parser.nested-simple3') { |f|
      RMail::Parser.new.parse(f)
    }

    assert_equal("\n", m.preamble)
    assert_equal("\n", m.part(0).preamble)
    assert_equal("\n", m.part(0).epilogue)
    assert_equal("\n\n", m.epilogue)
  end

  def test_parse_nested_multipart
    p = RMail::Parser.new
    m = data_as_file('parser.nested-multipart') { |f|
      p.parse(f)
    }

    # Verify preamble and epilogue
    assert_equal("This is level 1's preamble.\n", m.preamble)
    assert_equal("\nThis is level 1's epilogue.\n\n", m.epilogue)

    # Verify a smattering of headers
    assert_equal("multipart/mixed; boundary=\"=-=-=\"",
                 m.header['content-type'])
    assert_equal("Some nested multiparts", m.header['subject'])

    # Verify part 0
    begin
      part = m.part(0)
      assert_equal(0, part.header.length)
      assert_equal("Let's see here.\n", part.body)
    end

    # Verify part 1
    begin
      part = m.part(1)
      assert_nil(part.preamble)
      assert_nil(part.epilogue)
      assert_equal(1, part.header.length)
      assert_equal("inline", part.header['content-disposition'])
      assert_equal("This is the first part.\n", part.body)
    end

    # Verify part 2
    begin
      part = m.part(2)
      assert_equal(1, part.header.length)
      assert_equal("multipart/mixed; boundary=\"==-=-=\"",
                   part.header['content-type'])
      assert_equal("This is level 2's preamble.\n", part.preamble)
      assert_equal("This is level 2's epilogue.  It has no trailing end of line.", part.epilogue)

      # Verify part 2.0
      begin
        part = m.part(2).part(0)
        assert_nil(part.preamble)
        assert_nil(part.epilogue)
        assert_equal(1, part.header.length)
        assert_equal("inline", part.header['content-disposition'])
        assert_equal("This is the first nested part.\n", part.body)
      end

      # Verify part 2.1
      begin
        part = m.part(2).part(1)
        assert_nil(part.preamble)
        assert_nil(part.epilogue)
        assert_equal(1, part.header.length)
        assert_equal("inline", part.header['content-disposition'])
        assert_equal("This is the second nested part.\n", part.body)
      end

      # Verify part 2.2
      begin
        part = m.part(2).part(2)
        assert_equal(1, part.header.length)
        assert_equal("multipart/mixed; boundary=\"===-=-=\"",
                     part.header['content-type'])
        assert_equal("This is level 3's preamble.\n", part.preamble)
        assert_equal("This is level 3's epilogue.\n", part.epilogue)

        # Verify part 2.2.0
        begin
          part = m.part(2).part(2).part(0)
          assert_equal(0, part.header.length)
          assert_equal("This is the first doubly nested part.\n", part.body)
        end

        # Verify part 2.2.1
        begin
          part = m.part(2).part(2).part(1)
          assert_nil(part.preamble)
          assert_nil(part.epilogue)
          assert_equal(1, part.header.length)
          assert_equal("inline", part.header['content-disposition'])
          assert_equal("This is the second doubly nested part.\n", part.body)
        end
      end

      # Verify part 3
      begin
        part = m.part(3)
        assert_nil(part.preamble)
        assert_nil(part.epilogue)
        assert_equal(1, part.header.length)
        assert_equal("inline", part.header['content-disposition'])
        assert_equal("This is the third part.\n", part.body)
      end
    end
  end

  def test_parse_badmime1
    p = RMail::Parser.new
    1.upto(File.stat(data_filename('parser.badmime1')).size + 10) { |size|
      m = nil
      data_as_file('parser.badmime1') do |f|
        p.chunk_size = size
        assert_nothing_raised("failed for chunk size #{size.to_s}") {
          m = p.parse(f)
        }
      end
      assert_equal(m, p.parse(m.to_s))
    }
  end

  def test_parse_badmime2
    p = RMail::Parser.new
    1.upto(File.stat(data_filename('parser.badmime2')).size + 10) { |size|
      m = nil
      data_as_file('parser.badmime2') do |f|
        p.chunk_size = size
        assert_nothing_raised("failed for chunk size #{size.to_s}") {
          m = p.parse(f)
        }
      end
      assert_equal(m, p.parse(m.to_s))
    }
  end

  def test_parse_multipart_01
    m = data_as_file('parser/multipart.1') do |f|
      RMail::Parser.new.parse(f)
    end

    assert_equal("preamble", m.preamble)
    assert_equal("epilogue\n", m.epilogue)
    assert_equal(1, m.body.length)

    begin
      part = m.part(0)
      assert_equal(1, part.header.length)
      assert_nil(part.body)
      assert_nil(part.preamble)
      assert_nil(part.epilogue)
      assert_equal("part1", part.header[0])
    end

    delimiters, delimiters_boundary = m.get_delimiters
    assert_equal(["\n--aa\n", "\n--aa--\n"], delimiters)
    assert_equal("aa", delimiters_boundary)
  end

  def test_parse_multipart_02
    m = data_as_file('parser/multipart.2') do |f|
      RMail::Parser.new.parse(f)
    end

    assert_nil(m.preamble)
    assert_equal("\n", m.epilogue)
    assert_equal(1, m.body.length)

    begin
      part = m.part(0)
      assert_equal(0, part.header.length)
      assert_nil(part.body)
      assert_nil(part.preamble)
      assert_nil(part.epilogue)
    end

    delimiters, delimiters_boundary = m.get_delimiters
    assert_equal(["\n--aa\n", "\n--aa--\n"], delimiters)
    assert_equal("aa", delimiters_boundary)
  end

  def test_parse_multipart_03
    m = data_as_file('parser/multipart.3') do |f|
      RMail::Parser.new.parse(f)
    end

    assert_nil(m.preamble)
    assert_equal("", m.epilogue)
    assert_equal(1, m.body.length)

    begin
      part = m.part(0)
      assert_equal(0, part.header.length)
      assert_nil(part.body)
      assert_nil(part.preamble)
      assert_nil(part.epilogue)
    end

    delimiters, delimiters_boundary = m.get_delimiters
    assert_equal(["--aa\n", "--aa--\n"], delimiters)
    assert_equal("aa", delimiters_boundary)
  end

  def test_parse_multipart_04
    m = data_as_file('parser/multipart.4') do |f|
      RMail::Parser.new.parse(f)
    end

    assert_equal("preamble", m.preamble)
    assert_equal("epilogue\n", m.epilogue)
    assert_equal([], m.body)

    delimiters, delimiters_boundary = m.get_delimiters
    assert_equal(["\n--aa--\n"], delimiters)
    assert_equal("aa", delimiters_boundary)
  end

  def test_parse_multipart_05
    m = data_as_file('parser/multipart.5') do |f|
      RMail::Parser.new.parse(f)
    end

    assert_nil(m.preamble)
    assert_equal("", m.epilogue)
    assert_equal([], m.body)

    delimiters, delimiters_boundary = m.get_delimiters
    assert_equal(["--aa--\n"], delimiters)
    assert_equal("aa", delimiters_boundary)
  end

  def test_parse_multipart_06
    m = data_as_file('parser/multipart.6') do |f|
      RMail::Parser.new.parse(f)
    end

    assert_nil(m.preamble)
    assert_equal("", m.epilogue)
    assert_equal([], m.body)

    delimiters, delimiters_boundary = m.get_delimiters
    assert_equal(["\n--aa--\n"], delimiters)
    assert_equal("aa", delimiters_boundary)
  end

  def test_parse_multipart_07
    m = data_as_file('parser/multipart.7') do |f|
      RMail::Parser.new.parse(f)
    end

    assert_equal("preamble\n", m.preamble)
    assert_equal("", m.epilogue)
    assert_equal([], m.body)

    delimiters, delimiters_boundary = m.get_delimiters
    assert_equal(["\n--aa--\n"], delimiters)
    assert_equal("aa", delimiters_boundary)
  end

  def test_parse_multipart_08
    m = data_as_file('parser/multipart.8') do |f|
      RMail::Parser.new.parse(f)
    end

    assert_equal("preamble", m.preamble)
    assert_equal("epilogue", m.epilogue)
    assert_equal(1, m.body.length)

    delimiters, delimiters_boundary = m.get_delimiters
    assert_equal(["\n--aa\n", "\n--aa--\n"], delimiters)
    assert_equal("aa", delimiters_boundary)
  end

  def test_parse_multipart_09
    m = data_as_file('parser/multipart.9') do |f|
      RMail::Parser.new.parse(f)
    end

    assert_nil(m.preamble)
    assert_equal("", m.epilogue)
    assert_equal(1, m.body.length)

    delimiters, delimiters_boundary = m.get_delimiters
    assert_equal(["\n--aa\n", "\n--aa--"], delimiters)
    assert_equal("aa", delimiters_boundary)
  end

  def test_parse_multipart_10
    m = data_as_file('parser/multipart.10') do |f|
      RMail::Parser.new.parse(f)
    end

    assert_nil(m.preamble)
    assert_equal("", m.epilogue)
    assert_equal(0, m.body.length)

    delimiters, delimiters_boundary = m.get_delimiters
    assert_equal(["--aa--"], delimiters)
    assert_equal("aa", delimiters_boundary)
  end

  def test_parse_multipart_11
    m = data_as_file('parser/multipart.11') do |f|
      RMail::Parser.new.parse(f)
    end

    assert_equal("preamble", m.preamble)
    assert_equal("epilogue\n", m.epilogue)
    assert_equal(3, m.body.length)

    delimiters, delimiters_boundary = m.get_delimiters
    assert_equal(["\n--aa\t\n", "\n--aa \n", "\n--aa \t \t\n", "\n--aa-- \n"],
                 delimiters)
    assert_equal("aa", delimiters_boundary)
  end

  def test_parse_multipart_12
    m = data_as_file('parser/multipart.12') do |f|
      RMail::Parser.new.parse(f)
    end

    assert_equal("preamble\n--aaZ\npart1\n--aa ignored\npart2\n--aa \t \tignored\npart3\n--aa--ignored\nepilogue\n", m.preamble)
    assert_nil(m.epilogue)
    assert_equal(0, m.body.length)

    delimiters, delimiters_boundary = m.get_delimiters
    assert_equal([""], delimiters)
    assert_equal("aa", delimiters_boundary)
  end

  def test_parse_multipart_13
    m = data_as_file('parser/multipart.13') do |f|
      RMail::Parser.new.parse(f)
    end

    assert_equal("preamble", m.preamble)
    assert_nil(m.epilogue)
    assert_equal(1, m.body.length)

    delimiters, delimiters_boundary = m.get_delimiters
    assert_equal(["\n--aa\n", ""], delimiters)
    assert_equal("aa", delimiters_boundary)
  end

  def test_parse_multipart_14
    m = data_as_file('parser/multipart.14') do |f|
      RMail::Parser.new.parse(f)
    end

    assert_equal("preamble", m.preamble)
    assert_nil(m.epilogue)
    assert_equal(1, m.body.length)

    delimiters, delimiters_boundary = m.get_delimiters
    assert_equal(["\n--aa\n", ""], delimiters)
    assert_equal("aa", delimiters_boundary)
  end

  def test_parse_multipart_15
    m = data_as_file('parser/multipart.15') do |f|
      RMail::Parser.new.parse(f)
    end

    assert_equal("preamble\nline1\nline2\n", m.preamble)
    assert_nil(m.epilogue)
    assert_equal(0, m.body.length)

    delimiters, delimiters_boundary = m.get_delimiters
    assert_equal([""], delimiters)
    assert_equal("aa", delimiters_boundary)
  end

  def test_parse_multipart_16
    m = data_as_file('parser/multipart.16') do |f|
      RMail::Parser.new.parse(f)
    end

    assert_equal("preamble\nline1\nline2", m.preamble)
    assert_nil(m.epilogue)
    assert_equal(0, m.body.length)

    delimiters, delimiters_boundary = m.get_delimiters
    assert_equal([""], delimiters)
    assert_equal("aa", delimiters_boundary)
  end

  def test_rmail_parser_s_read

    string_msg = <<-EOF
From matt@lickey.com  Mon Dec 24 00:00:06 2001
From:    matt@example.net
To:   matt@example.com
Subject: test message

message body
has two lines
    EOF

    m = string_as_file(string_msg) { |f|
      RMail::Parser.read(f)
    }
    common_test_parse(m)

    m = RMail::Parser.read(string_msg)
    common_test_parse(m)
  end

  def test_s_new
    p = RMail::Parser.new
    assert_instance_of(RMail::Parser, p)
  end

end
