#!/usr/bin/env ruby
=begin
   Copyright (C) 2002 Matt Armstrong.  All rights reserved.

   Permission is granted for use, copying, modification, distribution,
   and distribution of modified versions of this work as long as the
   above copyright notice is included.
=end

require 'tests/testbase'

class TestRDeliver < TestBase

  attr_reader :home

  def setup
    super
    @old_home = ENV['HOME']
    @home = File.join(@scratch_dir, 'home')
    Dir.mkdir(@home)
    ENV['HOME'] = @home
  end

  def teardown
    ENV['HOME'] = @old_home
    super
  end

  def script
    File.join(Dir.getwd, 'bin', 'rdeliver.rb')
  end

  def test_rdeliver_syntax
    assert_equal(true, system(ruby_program + ' -c ' + script + ' >/dev/null'))
  end

  def test_rdeliver_home_arg
    home2 = home + '2'
    Dir.mkdir(home2)
    assert_equal(false, system(ruby_program, script, '--home', home2,
			       '--bogus'))
    assert_equal(75 << 8, $?)
    catastrophic = File.join(home2, 'CATASTROPHIC_DELIVERY_FAILURE')
    assert(test(?e, catastrophic))
    assert(file_contains(catastrophic, /unrecognized option.*--bogus/))
  end

  def test_rdeliver_load_path_arg
    Dir.mkdir(File.join(scratch_dir, 'mail'))
    File.open(File.join(scratch_dir, 'mail', 'lda.rb'), 'w') { |file|
      file.puts 'raise "test succeeded"'
    }
    assert_equal(false, system(ruby_program, script, '--load-path',
			       scratch_dir))
    assert_equal(75 << 8, $?)
    catastrophic = File.join(home, 'CATASTROPHIC_DELIVERY_FAILURE')
    assert(test(?e, catastrophic))
    assert(file_contains(catastrophic, /test succeeded/))
  end

  def test_rdeliver_bad_arg
    assert_equal(false, system(ruby_program, script, '--bogus'))
    assert_equal(75 << 8, $?)
    catastrophic = File.join(home, 'CATASTROPHIC_DELIVERY_FAILURE')
    assert(test(?e, catastrophic))
    assert(file_contains(catastrophic, /unrecognized option.*--bogus/))
  end

  def test_extra_arguments
    assert_equal(false, system(ruby_program, script, 'first',
			       'extra1', 'extra2'))
    assert_equal(75 << 8, $?)
    catastrophic = File.join(home, 'CATASTROPHIC_DELIVERY_FAILURE')
    assert(test(?e, catastrophic))
    assert(file_contains(catastrophic, /RuntimeError/))
    assert(file_contains(catastrophic, /extra arguments passed to.*\["extra1", "extra2"]/))
  end

  def test_homedir_chdir_failure
    Dir.rmdir(home)
    errors = scratch_filename('errors')
    assert_equal(false, system(format("'%s' '%s' --bogus > %s",
				      ruby_program, script, errors)))
    assert_equal(75 << 8, $?)
    catastrophic = File.join(home, 'CATASTROPHIC_DELIVERY_FAILURE')
    assert_equal(false, test(?e, catastrophic))
    assert(file_contains(errors, /unrecognized option.*--bogus/))
    assert(file_contains(errors, /Failed writing CATASTROPHIC/))
    assert(file_contains(errors, /Errno::ENOENT/))
    assert(file_contains(errors, Regexp.escape(home.inspect)))
  end

  def do_test_no_config_file(config)
    cmd = format("'%s' '%s' -I '%s' %s < /dev/null",
		 ruby_program, script, Dir.getwd, config.nil? ? '' : config)
    assert_equal(false, system(cmd))
    assert_equal(75 << 8, $?)
    catastrophic = File.join(home, 'CATASTROPHIC_DELIVERY_FAILURE')
    assert(test(?e, catastrophic))
    assert(file_contains(catastrophic, /Errno::ENOENT/))

    temp = config
    temp ||= '.rdeliver'
    assert(file_contains(catastrophic, Regexp.escape(File.join(home, temp))))
  end

  def test_no_dot_rdeliver
    assert_equal(false, system(format("'%s' '%s' -I '%s' < /dev/null",
				      ruby_program, script, Dir.getwd)))
    assert_equal(75 << 8, $?)
    catastrophic = File.join(home, 'CATASTROPHIC_DELIVERY_FAILURE')
    assert(test(?e, catastrophic))
    assert(file_contains(catastrophic, /Errno::ENOENT/))
    assert(file_contains(catastrophic,
			 Regexp.escape(File.join(home, '.rdeliver'))))
  end

  def test_no_dot_rdeliver2
    do_test_no_config_file(nil)
  end

  def test_no_config_file
    do_test_no_config_file("my-config")
  end

  def test_successful_deliver
    config_file = scratch_filename('config')
    File.open(config_file, 'w') { |f|
      f.puts <<EOF
def main
  lda.save('INBOX')
end
EOF
    }

    message = <<-EOF
    From: bob@example.net
    To: sally@example.net
    Subject: test message

    This is a test message
    EOF

    log = scratch_filename('log')
    command = format("'%s' '%s' -I '%s' -l '%s' '%s'",
                     ruby_program, script, Dir.getwd, log, config_file)
    IO.popen(command, 'w') { |io|
      message.each_line { |line|
        line = line.sub(/^\s+/, '')
        io.puts(line)
      }
    }

    assert_equal(0, $?)
    assert(test(?e, log))
    inbox = File.join(home, 'INBOX')
    assert(test(?e, log))
    assert(test(?e, inbox))
    assert(file_contains(log, /action.*save to.*INBOX/i))

    # FIXME: need a generic 'test a valid mbox' method
    assert(file_contains(inbox, /^Subject: test message$/))
    assert(file_contains(inbox, /^From .*\d{4}$/))
    assert(file_contains(inbox, /^This is a test message$/))
  end

end
