#!/usr/bin/env ruby
=begin
   Copyright (C) 2001, 2002 Matt Armstrong.  All rights reserved.

   Permission is granted for use, copying, modification, distribution,
   and distribution of modified versions of this work as long as the
   above copyright notice is included.
=end

require 'tests/testbase'
require 'mail/deliver'
require 'tempfile'

class TestMailDeliver < TestBase

  FROM_RE = /^From \S+@\S+  (Mon|Tue|Wed|Thu|Fri|Sat|Sun) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) [ \d]\d \d{2}:\d{2}:\d{2} \d{4}$/

  # Validates an mbox style mailbox and returns the number of messages
  # it contains.
  def validate_mbox(filename, sentinel)
    mailcount = 0
    line_count = 1
    message_line_count = 0
    body_line_count = -1
    prevline = nil
    sentinel_match = true
    IO.foreach(filename) { |line|
      assert(line[-1] == ?\n,
	     "Line #{line_count} #{line.inspect} does not end in a newline")

      if (line_count == 1)
	assert_match(line, FROM_RE, 'invalid From_')
      end

      if ((line_count == 1 || prevline == "\n") && line =~ /^From /)
	mailcount += 1
	message_line_count = 0
	assert(prevline.nil? || body_line_count >= 0, "No body found")
	body_line_count = -1
	unless sentinel.nil?
	  assert(sentinel_match, "Mail did not contain sentinel " +
		 sentinel.inspect)
	  sentinel_match = false
	end
      end

      if body_line_count < 0 && line =~ /^$/
	body_line_count = 0
      end

      unless sentinel.nil?
	if line =~ sentinel
	  sentinel_match = true
	end
      end

      if (message_line_count == 1)
	assert_match(line, /^\S+:/,
		     "Message at line #{line_count} does not begin " +
		     "with headers")
      end

      prevline = line
      line_count += 1
      message_line_count += 1
      body_line_count += 1 if body_line_count >= 0
    }
    assert(sentinel_match, "Mail did not contain sentinel " +
	   sentinel.inspect) unless sentinel.nil?
    return mailcount
  end

  def test_deliver_mbox_atime_preserve()
    mailbox = File.join(scratch_dir, "mbox.atime_preserve")
    File.open(mailbox, 'w') {}
    File.utime(0, File.stat(mailbox).mtime, mailbox)
    assert_equal(0, File.stat(mailbox).atime)
    Mail::Deliver.deliver_mbox(mailbox, "message")
    assert_equal(0, File.stat(mailbox).atime,
                 "failed to preserve access time on mailbox")
  end

  def test_deliver_mbox_verify_is_mbox()
    [ "\n",
      "\n\n",
      "From ",
      "From foo@bar\nyo",
      "From foo@bar\nblah\n" ].each { |contents|
      mailbox = File.join(scratch_dir, "mbox.not_an_mbox")
      File.open(mailbox, 'w') { |f|
        f.write(contents)
      }
      e = assert_exception(Mail::Deliver::NotAMailbox) {
        Mail::Deliver.deliver_mbox(mailbox, "message")
      }
      assert_match(/file is not in mbox format/, e.message)
    }

    [ "",
      "From \n\n",
      "From foo@bar\nblah\n\n" ].each { |contents|
      mailbox = File.join(scratch_dir, "mbox.valid_mbox")
      File.open(mailbox, 'w') { |f|
        f.write(contents)
      }
      assert_no_exception {
        Mail::Deliver.deliver_mbox(mailbox, "message")
      }
    }

    string_as_file("") { |file|
      symlink = scratch_filename("symlink")
      File::symlink(file.path, symlink)
      assert(File::symlink?(symlink))
      assert_exception(Mail::Deliver::NotAFile) {
        Mail::Deliver.deliver_mbox(symlink, "message")
      }
    }
  end

  def test_deliver_mbox_dev_null()
    Mail::Deliver.deliver_mbox('/dev/null', "message")
  end

  def test_deliver_mbox_no_each_method()
    mailbox = File.join(scratch_dir, "mbox.no_each_method")

    assert(!test(?e, mailbox))
    e = assert_exception(NO_METHOD_ERROR) {
      Mail::Deliver.deliver_mbox(mailbox, nil)
    }
    assert_not_nil(e)
    assert_match(/undefined method `each'/, e.message)

    assert(test(?f, mailbox))
    assert(test(?z, mailbox))
    assert_equal(0, validate_mbox(mailbox, nil))
    e = assert_exception(NO_METHOD_ERROR) {
      Mail::Deliver.deliver_mbox(mailbox, Object.new)
    }
    assert_not_nil(e)
    assert(test(?f, mailbox))
    assert(test(?z, mailbox))
    assert_equal(0, validate_mbox(mailbox, nil))
    assert_match(/undefined method `each'/, e.message)
  end

  def test_deliver_mbox_string_with_from()
    mailbox = File.join(scratch_dir, "mbox.string_with_from")
    assert(!test(?e, mailbox))
    string_message =
      "From baz@bango  Fri Nov  9 23:00:43 2001\nX-foo: foo\n\nfoo"
    Mail::Deliver.deliver_mbox(mailbox, string_message)
    assert(test(?f, mailbox))
    assert_equal(string_message.length + 2, test(?s, mailbox))
    assert_equal(1, validate_mbox(mailbox, /^From baz@bango/))
  end

  def test_deliver_mbox_string_without_from()
    mailbox = File.join(scratch_dir, "mbox.string_without_from")
    assert(!test(?e, mailbox))
    string_message = "X-foo: foo\n\nfoo"
    Mail::Deliver.deliver_mbox(mailbox, string_message)
    assert(test(?f, mailbox))
    assert_equal("From foo@bar  Fri Nov  9 23:00:43 2001\n".length +
		 string_message.length + 2, test(?s, mailbox))
    assert_equal(1, validate_mbox(mailbox, /^foo$/))
  end

  def test_deliver_mbox_array_with_from()
    mailbox = File.join(scratch_dir, "mbox.array_with_from")
    assert(!test(?e, mailbox))
    array_message = [
      'From baz@bango  Fri Nov  9 23:00:43 2001',
      'X-foo: foo',
      '',
      'foo' ]
    Mail::Deliver.deliver_mbox(mailbox, array_message)
    assert(test(?f, mailbox))
    assert_equal(array_message.join("\n").length + 2, test(?s, mailbox))
    assert_equal(1, validate_mbox(mailbox, /^foo$/))
  end

  def test_deliver_mbox_array_without_from()
    mailbox = File.join(scratch_dir, "mbox.array_without_from")
    assert(!test(?e, mailbox))
    array_message = [
      'X-foo: foo',
      '',
      'foo' ]
    Mail::Deliver.deliver_mbox(mailbox, array_message)
    assert(test(?f, mailbox))
    assert_equal("From baz@bar  Fri Nov  9 23:00:43 2001\n".length +
		 array_message.join("\n").length + 2, test(?s, mailbox))
    assert_equal(1, validate_mbox(mailbox, /^foo$/))
  end

  def test_deliver_mbox_complex()
    mailbox = scratch_filename("mbox.complex")
    obj = Object.new

    def obj.each
      yield "x-header: header value"
      yield ""
      yield "complex body text"
      yield "complex body text again"
      yield "From is escaped"
      yield "From. not escaped"
    end
    def obj.mbox_from
      "From complex@object  Fri Nov  9 23:00:43 2001"
    end

    assert(!test(?e, mailbox))
    Mail::Deliver.deliver_mbox(mailbox, obj)
    Mail::Deliver.deliver_mbox(mailbox, obj)
    assert(test(?f, mailbox))
    assert_equal(282, test(?s, mailbox))
    assert_equal(2, validate_mbox(mailbox, /^complex body text again$/))

    File.open(mailbox) {|f|
      # make sure leading body "From " lines are escaped
      f.grep(/is escaped/).each {|escaped|
	assert_match(/^>From /, escaped)
      }
      # but not all "From" lines are escaped
      f.grep(/.?From[^ ]/).each {|escaped|
	assert_not_match(/^>From /, escaped)
      }
      # make sure the From_ headers are what obj.get_mbox_from returns
      f.grep(/From /).each {|from|
	assert_equal(obj.mbox_from + "\n", from)
      }
    }
  end

  def test_deliver_mbox_flock_timeout()
    mailbox = scratch_filename("mbox")
    File.open(mailbox, 'w') { |file|
      file.flock(File::LOCK_EX)

      e = assert_exception(Mail::Deliver::LockingError) {
        Mail::Deliver.deliver_mbox(mailbox, "message")
      }
      assert_equal("Timeout locking mailbox.", e.message)
    }
  end

  def test_deliver_mbox_random_exception()
    mailbox = scratch_filename("mbox")

    obj = Object.new
    def obj.each
      10.times { |i|
        yield "Header#{i}: foo bar baz"
      }
      raise "No more already!"
    end

    e = assert_exception(RuntimeError) {
      Mail::Deliver.deliver_mbox(mailbox, obj)
    }
    assert_equal("No more already!", e.message)
    assert_equal(0, File::stat(mailbox).size)

    Mail::Deliver.deliver_mbox(mailbox, "this\nis\na\nmessage!")
    size = File::stat(mailbox).size

    e = assert_exception(RuntimeError) {
      Mail::Deliver.deliver_mbox(mailbox, obj)
    }
    assert_equal("No more already!", e.message)
    assert_equal(size, File::stat(mailbox).size)
  end

  def test_deliver_pipe_no_each_method()
    output = File.join(scratch_dir, "pipe.no_each_method")
    command = "/bin/cat > #{output}"

    assert_equal(false, test(?e, output))
    e = assert_exception(NO_METHOD_ERROR) {
      Mail::Deliver.deliver_pipe(command, nil)
    }
    assert_not_nil(e)
    assert_match(/undefined method `each'/, e.message)
    assert_equal(true, test(?e, output))
    assert_equal(true, test(?z, output))

    e = assert_exception(NO_METHOD_ERROR) {
      Mail::Deliver.deliver_pipe(command, Object.new)
    }
    assert_not_nil(e)
    assert_match(/undefined method `each'/, e.message)
    assert_equal(true, test(?e, output))
    assert_equal(true, test(?z, output))
  end

  def test_deliver_pipe_simple()
    output = File.join(scratch_dir, "pipe.simple")
    command = "/bin/cat > #{output}"

    message1 = "This is message one."
    assert_equal(false, test(?e, output))
    Mail::Deliver.deliver_pipe(command, message1)
    got = File.open(output).readlines().join('')
    assert_equal(message1 + "\n", got)

    message2 = %q{This is message two.
It has some newlines in it.
And it even ends with one.
}
    Mail::Deliver.deliver_pipe(command, message2)
    got = File.open(output).readlines().join('')
    assert_equal(message2, got)

    message3 = [ "Line 1", "Line 2", "", "Line 3" ]
    Mail::Deliver.deliver_pipe(command, message3)
    got = File.open(output).readlines().join('')
    assert_equal(message3.join("\n") + "\n", got)
  end

  def test_deliver_pipe_failed()
    command = "/bin/sh -c 'exit 7'"
    Mail::Deliver.deliver_pipe(command, "irrelevant message")
    assert_equal(7 << 8, $?)

    # now attempt to generate an EPIPE pipe error
    long_message = []
    0.upto(5000) {
      long_message.push("This is a line of text")
    }
    Mail::Deliver.deliver_pipe(command, long_message)
    assert_equal(7 << 8, $?)
  end

  def test_deliver_maildir
    require 'socket'

    dir = scratch_filename('Maildir')
    delivered_to = Mail::Deliver.deliver_maildir(dir, 'message')
    assert(FileTest::directory?(dir))
    assert(FileTest::directory?(File.join(dir, 'tmp')))
    assert(FileTest::directory?(File.join(dir, 'new')))
    assert(FileTest::directory?(File.join(dir, 'cur')))

    #
    # Make sure the file is delivered to the right filename
    #
    assert_kind_of(String, delivered_to)
    newdir_re = Regexp.escape(File.join(dir, 'new'))
    hostname_re = Regexp.escape(Socket::gethostname)
    pid_re = Regexp.escape(Process::pid.to_s)
    assert_match(/#{newdir_re}\/\d+\.#{pid_re}_\d+\.#{hostname_re}$/,
                 delivered_to)
    /#{newdir_re}\/(\d+)/ =~ delivered_to
    assert_operator(10, '>', Time.now.to_i - Integer($1).to_i)
    assert_operator(0, '<=', Time.now.to_i - Integer($1).to_i)

    #
    # Make sure that file contains the message
    #
    assert(FileTest::file?(delivered_to))
    lines = IO::readlines(delivered_to)
    assert_equal("message\n", lines[0])
    assert_nil(lines[1])

    #
    # Make sure the tmp name is gone
    #
    assert(!FileTest::file?(File.join(dir, 'tmp',
                                      File::basename(delivered_to))))
  end

  def test_deliver_maildir_twice
    dir = scratch_filename('Maildir')
    first = Mail::Deliver.deliver_maildir(dir, 'message_first')
    second = Mail::Deliver.deliver_maildir(dir, 'message_second')

    #
    # Validate that the filenames look sane
    #
    assert(!(first == second))
    assert_kind_of(String, first)
    assert_kind_of(String, second)
    File.basename(first) =~ /^\d+\.\d+_(\d+)/
    first_seq = $1
    File.basename(second) =~ /^\d+\.\d+_(\d+)/
    second_seq = $1
    assert(Integer(first_seq) + 1 == Integer(second_seq))

    #
    # Validate that the messages look sane
    #
    assert_equal("message_first\n", IO::readlines(first)[0])
    assert_nil(IO::readlines(first)[1])
    assert_equal("message_second\n", IO::readlines(second)[0])
    assert_nil(IO::readlines(second)[1])
  end

  def test_deliver_maildir_with_mbox_from
    message = <<EOF
From bob@example
content
EOF
    delivered_to = Mail::Deliver.deliver_maildir(scratch_filename('Maildir'),
                                                 message)
    assert_equal("content\n", IO::readlines(delivered_to)[0])
    assert_nil(IO::readlines(delivered_to)[1])
  end

  def test_deliver_maildir_one_tmp_file_conflict
    dir = scratch_filename('Maildir')

    # First, figure out what sequence number we're at
    sequence =
      maildir_sequence_from_file(Mail::Deliver.deliver_maildir(dir, 'foo'))
    sequence = sequence.succ

    # Next create the next possible tmp file
    conflicting = maildir_fill_tmp_files(dir, sequence, 1)

    # Then deliver
    start_time = Time.now
    delivered_to = Mail::Deliver.deliver_maildir(dir, 'the message')
    end_time = Time.now

    # Make sure the conflicting temp files didn't get clobbered
    maildir_verify_conflicting_tmp_files(conflicting)

    # Make sure we didn't sleep too long
    assert_operator(1.5, '<', end_time - start_time,
                    "Did not sleep long enough.")
    assert_operator(4.0, '>', end_time - start_time,
                    "Slept too long.")
  end

  def test_deliver_maildir_too_many_tmp_file_conflicts
    # Tests that if all possible tmp files are present, the function
    # throws an exception.
    dir = scratch_filename('Maildir')

    # First, figure out what sequence number we're at
    sequence =
      maildir_sequence_from_file(Mail::Deliver.deliver_maildir(dir, 'foo'))
    sequence = sequence.succ

    # Next create the next possible tmp file.  The delivery won't take
    # more than 10 seconds, so create 11 seconds worth of tmp files.
    conflicting = maildir_fill_tmp_files(dir, sequence, 11)

    # Then deliver
    start_time = Time.now
    assert_exception(Errno::EEXIST) {
      Mail::Deliver.deliver_maildir(dir, 'the message')
    }
    end_time = Time.now

    # Make sure the conflicting temp files didn't get clobbered
    maildir_verify_conflicting_tmp_files(conflicting)

    # Make sure we didn't sleep too long
    assert_operator(7.5, '<', end_time - start_time,
                    "Did not sleep long enough.")
    assert_operator(10, '>', end_time - start_time, "Slept too long.")
  end

  def test_deliver_maildir_is_file
    dir = scratch_filename('Maildir')
    File.open(dir, "w") { |f| f.puts "this is a file, not a directory" }
    assert(FileTest::file?(dir))
    e = assert_exception(Errno::EEXIST) {
      Mail::Deliver.deliver_maildir(dir, 'message')
    }
    assert_match(/File exists.*#{Regexp::escape(dir)}/, e.message)
  end

  def maildir_fill_tmp_files(dir, sequence, seconds_count)
    now = Time::now.to_i
    conflicting = []
    now.upto(now + seconds_count) { |time|
      name = sprintf("%d.%d_%d.%s", time, Process::pid, sequence,
                     Socket::gethostname)
      tmp_name = File.join(dir, 'tmp', name)
      conflicting << tmp_name
      File.open(tmp_name, 'w') { |f| f.puts "conflicting temp file" }
    }
    conflicting
  end

  def maildir_verify_conflicting_tmp_files(conflicting)
    conflicting.each { |conflicting_tmp|
      assert(FileTest::file?(conflicting_tmp),
             "Conflicting temp file got deleted.")
      assert_equal("conflicting temp file\n",
                   IO::readlines(conflicting_tmp)[0],
                   "Conflicting temp file got modified.")
      assert_nil(IO::readlines(conflicting_tmp)[1],
                 "Conflicting temp file was appended to.")
    }
  end

  def maildir_sequence_from_file(file)
    # First, figure out what sequence number we're at
    if File.basename(file) =~ /^\d+\.\d+_(\d+)/
      $1
    else
      raise "#{file} isn't valid"
    end
  end

  def helper_for_new_cur_tmp_is_file(subdir)
    dir = scratch_filename('Maildir')
    Dir.mkdir(dir)
    file = File.join(dir, subdir)
    File.open(file, 'w') { |f|
      f.puts "this is a file, not a directory"
    }
    assert(FileTest::file?(file))
    e = assert_exception(Errno::EEXIST) {
      Mail::Deliver.deliver_maildir(dir, 'message')
    }
    assert_match(/File exists.*#{Regexp::escape(file)}/, e.message)
  end

  def test_deliver_maildir_new_is_file
    helper_for_new_cur_tmp_is_file('new')
  end

  def test_deliver_maildir_cur_is_file
    helper_for_new_cur_tmp_is_file('cur')
  end

  def test_deliver_maildir_tmp_is_file
    helper_for_new_cur_tmp_is_file('tmp')
  end

end
