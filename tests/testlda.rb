#!/usr/bin/env ruby
#
#   Copyright (c) 2001 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

require 'tests/testbase'
require 'mail/lda'

class TestMailLDA < TestBase
  def setup
    super
    @message_filename = File.join(scratch_dir, "message")
    File.open(@message_filename, "w") { |f|
      f.write(<<EOF)
From: test-from@example.com
To: test-to@example.com
Subject: this is a test message

This is a test message
EOF
    }

    @reject_script_filename = File.join(scratch_dir, "reject.rb")
    @reject_log = File.join(scratch_dir, "reject.log")
    File.open(@reject_script_filename, "w") { |f|
      f.write(<<EOF)
require 'mail/lda'
mail = File.open("#{@message_filename}", "r")
lda = Mail::LDA.new(mail, "#{@reject_log}")
lda.reject()
EOF
    }

    @defer_script_filename = File.join(scratch_dir, "defer.rb")
    @defer_log = File.join(scratch_dir, "defer.log")
    File.open(@defer_script_filename, "w") { |f|
      f.write(<<EOF)
require 'mail/lda'
mail = File.open("#{@message_filename}", "r")
lda = Mail::LDA.new(mail, "#{@defer_log}")
lda.defer()
EOF
    }
  end

  def deliver_bounce(script, log, exitcode, exit_description)
    assert_equal(false, test(?e, log))
    assert_equal(false, system(ruby_bin, script))
    assert_equal(exitcode, $?)
    assert_equal(true, test(?e, log))
    assert_not_nil(test(?s, log))
    assert_operator(0, "<", test(?s, log))
    
    File.open(log, "r") { |f|
      blank_lines = f.grep(/^\s*$/)
      assert_equal(0, blank_lines.length)

      f.seek(0, IO::SEEK_SET)
      subject = f.grep(/Subject:/)
      assert_equal(1, subject.length)
      assert_match(/\d+: Subject: this is a test message/, subject[0])

      f.seek(0, IO::SEEK_SET)
      from = f.grep(/From:/)
      assert_equal(1, from.length)
      assert_match(/\d+: From: test-from@example\.com/, from[0])

      f.seek(0, IO::SEEK_SET)
      from = f.grep(/To:/)
      assert_equal(1, from.length)
      assert_match(/\d+: To: test-to@example\.com/, from[0])

      f.seek(0, IO::SEEK_SET)
      from = f.grep(/Action:/)
      assert_equal(1, from.length, "from is #{from.inspect}")
      assert_match(/\d+: Action: #{exit_description}$/, from[0])
    }
  end

  def test_delivery()
    deliver_bounce(@reject_script_filename, @reject_log, 77 << 8, "reject")
    deliver_bounce(@defer_script_filename, @defer_log, 75 << 8, "defer")

    from_re = /^From .*?@.*?  (Mon|Tue|Wed|Thu|Fri|Sat|Sun) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) [ \d]\d \d{2}:\d{2}:\d{2} \d{4}/

    # Now test successful delivery
    mailbox = File.join(scratch_dir, "mailbox")
    logfile = File.join(scratch_dir, "logfile")
    assert_equal(false, test(?e, mailbox))
    assert_equal(false, test(?e, logfile))
    lda = Mail::LDA.new(nil, logfile)
    lda.save(mailbox, true)
    assert_equal(true, test(?e, mailbox))
    assert_equal(true, test(?e, logfile))
    File.open(mailbox, "r") { |f|
      lines = f.readlines
      f.close
      assert_match(from_re, lines[0])
      assert_equal(["\n", "\n"], lines[1, lines.length - 1])
    }
    assert_equal(2, File.delete(mailbox, logfile))
    assert_equal(false, test(?e, mailbox))
    assert_equal(false, test(?e, logfile))

    # Now test succesful delivery with a real message
    mailbox = File.join(scratch_dir, "mailbox")
    logfile = File.join(scratch_dir, "logfile")
    assert_equal(false, test(?e, mailbox))
    assert_equal(false, test(?e, logfile))
    File.open(@message_filename, "r") { |f|
      lda = Mail::LDA.new(f, logfile)
      f.close
      lda.save(mailbox, true)
      assert_equal(true, test(?e, mailbox))
      assert_equal(true, test(?e, logfile))
      File.open(mailbox, "r") { |f|
	lines = f.readlines
	f.close
	assert_match(from_re, lines[0])
	assert_equal(["From: test-from@example.com\n",
		       "To: test-to@example.com\n",
		       "Subject: this is a test message\n",
		       "\n",
		       "This is a test message\n",
		       "\n"],
		     lines[1,lines.length - 1])
      }
    }
  end

  def test_nil_log
    assert_no_exception() {
      File.open(@message_filename) {|f|
	Mail::LDA.new(f, nil)
      }
    }
  end

  # Test message access functions of Mail::LDA
  def test_message_access
    lda = nil
    File.open(@message_filename) {|f|
      lda = Mail::LDA.new(f, nil)
    }
    assert_not_nil(lda)
    
    # Test the message method, to get at the message itself
    assert_respond_to(:message, lda)
    assert_not_nil(lda.message)
    assert_respond_to(:body, lda.message)
    assert_respond_to(:header, lda.message)
    assert_kind_of(Mail::Message, lda.message)

    # Test the header method, to get at the message header itself
    assert_respond_to(:header, lda)
    assert_not_nil(lda.header)
    assert_respond_to(:add, lda.header)
    assert_kind_of(Mail::Header, lda.header)
    assert_same(lda.message.header, lda.header)

    # Test the body method, to get at the message body itself
    assert_respond_to(:body, lda)
    assert_not_nil(lda.body)
    assert_respond_to(:each, lda.body)
    assert_respond_to(:grep, lda.body)
    assert_kind_of(Array, lda.body)
    assert_same(lda.message.body, lda.body)
    
    # Test the get method, to get at the headers
    assert_respond_to(:get, lda)
    assert_not_nil(lda.get('from'))
    assert_equal("test-from@example.com\n", lda.get('from'))
  end
end

if __FILE__ == $0
  require 'runit/cui/testrunner'
  RUNIT::CUI::TestRunner.run(TestMailLDA.suite)
end
