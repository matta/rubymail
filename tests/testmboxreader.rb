#!/usr/bin/env ruby
#--
#   Copyright (c) 2002 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

require 'tests/testbase'
require 'rmail/mailbox/mboxreader'

class TextRMailMBoxReader < TestBase

  def test_mbox_s_new
    r = RMail::Mailbox::MBoxReader.new("")
    assert_instance_of(RMail::Mailbox::MBoxReader, r)
  end

  def test_mbox_simple
    data_as_file("mbox.simple") { |f|
      mbox = RMail::Mailbox::MBoxReader.new(f)

      chunk = mbox.read(nil)
      assert_equal("From foo@bar  Wed Nov 27 12:27:32 2002\nmessage1\n",
                   chunk)
      chunk = mbox.read(nil)
      assert_nil(chunk)
      mbox.next

      chunk = mbox.read(nil)
      assert_equal("From foo@bar  Wed Nov 27 12:27:36 2002\nmessage2\n",
                   chunk)
      chunk = mbox.read(nil)
      assert_nil(chunk)
      mbox.next

      chunk = mbox.read(nil)
      assert_equal("From foo@bar  Wed Nov 27 12:27:40 2002\nmessage3\n",
                   chunk)
      chunk = mbox.read(nil)
      assert_nil(chunk)

      mbox.next
      chunk = mbox.read(nil)
      assert_nil(chunk)
    }
  end

  def test_mbox_odd
    data_as_file("mbox.odd") { |f|
      mbox = RMail::Mailbox::MBoxReader.new(f)

      chunk = mbox.read(nil)
      assert_equal("From foo@bar  Wed Nov 27 12:27:36 2002\nmessage1\n",
                   chunk)
      chunk = mbox.read(nil)
      assert_nil(chunk)
      mbox.next

      chunk = mbox.read(nil)
      assert_equal("From foo@bar  Wed Nov 27 12:27:40 2002\nmessage2\n",
                   chunk)
      chunk = mbox.read(nil)
      assert_nil(chunk)

      mbox.next
      chunk = mbox.read(nil)
      assert_nil(chunk)
    }
  end

  def t_chunksize_helper(reader, expected)
    chunk = reader.read(nil)
    assert_equal(expected, chunk)
  end

  def test_mbox_chunksize
    1.upto(80) { |chunk_size|
      data_as_file("mbox.simple") { |f|
        mbox = RMail::Mailbox::MBoxReader.new(f)

        mbox.chunk_size = chunk_size

        t_chunksize_helper(mbox,
           "From foo@bar  Wed Nov 27 12:27:32 2002\nmessage1\n")
        mbox.next
        t_chunksize_helper(mbox,
           "From foo@bar  Wed Nov 27 12:27:36 2002\nmessage2\n")
        mbox.next
        t_chunksize_helper(mbox,
           "From foo@bar  Wed Nov 27 12:27:40 2002\nmessage3\n")
        mbox.next

        chunk = mbox.read
        assert_nil(chunk)
      }
    }
  end

  def t_randomly_randomize(template)
    count = rand(10)
    messages = []
    0.upto(count) { |i|
      messages << template[0, 5 + rand(template.length - 5)] + "\n"
    }
    mbox_string = messages.join("\n")
    return [ messages, mbox_string ]
  end

  def t_randomly_parse_messages(reader)
    messages = []
    while message = reader.read(nil)
      messages << message
      reader.next
    end
    return messages
  end

  def t_randomly_parse_helper(chunk_size, messages, mbox_string)
    reader = RMail::Mailbox::MBoxReader.new(mbox_string)
    reader.chunk_size = chunk_size unless chunk_size.nil?

    messages2 = t_randomly_parse_messages(reader)
    assert_equal(messages, messages2)
  end

  def test_mbox_randomly
    5.times {
      template = ("From foo@bar\n" +
                  "text1\ntext2\ntext3\ntexttexttexttexttext4\n" +
                  (("abcdefghijklmnopqrstuvwxyz" * rand(5)) + "\n") * rand(20))

      messages, mbox_string = t_randomly_randomize(template)

      1.upto(200) { |chunk_size|
        t_randomly_parse_helper(chunk_size, messages, mbox_string)
      }
      t_randomly_parse_helper(nil, messages, mbox_string)
    }
  end

end
