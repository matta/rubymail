#!/usr/bin/env ruby
=begin
   Copyright (C) 2002 Matt Armstrong.  All rights reserved.

   Permission is granted for use, copying, modification,
   distribution, and distribution of modified versions of this work
   as long as the above copyright notice is included.
=end

require 'tests/testbase'
require 'mail/parser'

class TestMailParser < TestBase

  def test_parse
    p = Mail::Parser.new
    assert_instance_of(Mail::Parser, p)

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
    assert_instance_of(Mail::Message, m)
    assert_equal("From matt@lickey.com  Mon Dec 24 00:00:06 2001\n",
                 m.header.mbox_from)
    assert_equal("matt@example.net\n", m.header[0])
    assert_equal("matt@example.net\n", m.header['from'])
    assert_equal("matt@example.com\n", m.header[1])
    assert_equal("matt@example.com\n", m.header['to'])
    assert_equal("test message\n", m.header[2])
    assert_equal("test message\n", m.header['subject'])
    assert_equal("message body\nhas two lines\n", m.body)
  end

  def test_parse_simple_mime
    p = Mail::Parser.new
    m = data_as_file('parser.simple-mime') { |f|
      p.parse(f)
    }
    assert_instance_of(Mail::Message, m)
    assert_equal("Nathaniel Borenstein <nsb@bellcore.com>\n", m.header[0])
    assert_equal("Nathaniel Borenstein <nsb@bellcore.com>\n", m.header['from'])
    assert_equal("Ned Freed <ned@innosoft.com>\n", m.header[1])
    assert_equal("Ned Freed <ned@innosoft.com>\n", m.header['To'])
    assert_equal("Sun, 21 Mar 1993 23:56:48 -0800 (PST)\n", m.header[2])
    assert_equal("Sun, 21 Mar 1993 23:56:48 -0800 (PST)\n",
                 m.header['Date'])
    assert_equal("Sun, 21 Mar 1993 23:56:48 -0800 (PST)\n",
                 m.header['Date'])
    assert_equal("Sample message\n", m.header[3])
    assert_equal("Sample message\n", m.header['Subject'])
    assert_equal("1.0\n", m.header[4])
    assert_equal("1.0\n", m.header['MIME-Version'])
    assert_equal("multipart/mixed; boundary=\"simple boundary\"\n",
                 m.header[5])
    assert_equal("multipart/mixed; boundary=\"simple boundary\"\n",
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
    assert_equal("text/plain; charset=us-ascii\n",
                 m.part(1).header['content-type'])

    # Verify the epilogue
    assert_equal("\nThis is the epilogue.  It is also to be ignored.\n",
                 m.epilogue)
  end

  def test_parse_nested_simple
    m = data_as_file('parser.nested-simple') { |f|
      Mail::Parser.new.parse(f)
    }
    assert_nil(m.preamble)
    assert_nil(m.part(0).preamble)
    assert_nil(m.part(0).epilogue)
    assert_nil(m.epilogue)

    m = data_as_file('parser.nested-simple2') { |f|
      Mail::Parser.new.parse(f)
    }

    assert_equal("", m.preamble)
    assert_equal("", m.part(0).preamble)
    assert_equal("", m.part(0).epilogue)
    assert_equal("\n", m.epilogue)
  end

  def test_parse_nested_multipart
    p = Mail::Parser.new
    m = data_as_file('parser.nested-multipart') { |f|
      p.parse(f)
    }

    # Verify preamble and epilogue
    assert_equal("This is level 1's preamble.\n", m.preamble)
    assert_equal("\nThis is level 1's epilogue.\n\n", m.epilogue)

    # Verify a smattering of headers
    assert_equal("multipart/mixed; boundary=\"=-=-=\"\n",
                 m.header['content-type'])
    assert_equal("Some nested multiparts\n", m.header['subject'])

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
      assert_equal("inline\n", part.header['content-disposition'])
      assert_equal("This is the first part.\n", part.body)
    end

    # Verify part 2
    begin
      part = m.part(2)
      assert_equal(1, part.header.length)
      assert_equal("multipart/mixed; boundary=\"==-=-=\"\n",
                   part.header['content-type'])
      assert_equal("This is level 2's preamble.\n", part.preamble)
      assert_equal("This is level 2's epilogue.  It has no trailing end of line.", part.epilogue)

      # Verify part 2.0
      begin
        part = m.part(2).part(0)
        assert_nil(part.preamble)
        assert_nil(part.epilogue)
        assert_equal(1, part.header.length)
        assert_equal("inline\n", part.header['content-disposition'])
        assert_equal("This is the first nested part.\n", part.body)
      end

      # Verify part 2.1
      begin
        part = m.part(2).part(1)
        assert_nil(part.preamble)
        assert_nil(part.epilogue)
        assert_equal(1, part.header.length)
        assert_equal("inline\n", part.header['content-disposition'])
        assert_equal("This is the second nested part.\n", part.body)
      end

      # Verify part 2.2
      begin
        part = m.part(2).part(2)
        assert_equal(1, part.header.length)
        assert_equal("multipart/mixed; boundary=\"===-=-=\"\n",
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
          assert_equal("inline\n", part.header['content-disposition'])
          assert_equal("This is the second doubly nested part.\n", part.body)
        end
      end

      # Verify part 3
      begin
        part = m.part(3)
        assert_nil(part.preamble)
        assert_nil(part.epilogue)
        assert_equal(1, part.header.length)
        assert_equal("inline\n", part.header['content-disposition'])
        assert_equal("This is the third part.\n", part.body)
      end
    end
  end

  def test_parse_rfc822
    p = Mail::Parser.new
    m = data_as_file('parser.rfc822') do |f|
      p.parse(f)
    end
    # FIXME: not finished
  end

  def test_s_new
    p = Mail::Parser.new
    assert_instance_of(Mail::Parser, p)
  end

end
