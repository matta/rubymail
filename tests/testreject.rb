#!/usr/bin/env ruby
#
#   Copyright (c) 2001 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

require 'mailaudit'
require 'testbase'

require 'rbconfig.rb'
include Config

class TestMailReject < TestBase

  def setup
    super
    @script_file = File.join(test_dir, "reject.rb")
    reject_template = %q{
      require 'mailaudit'
      audit = MailAudit.new(File.open('/dev/null'), '%s')
      audit.log(1, "about to fail")
      audit.%s
    }
    @reject_script = sprintf(reject_template, @log_file, 'reject')
    @defer_script = sprintf(reject_template, @log_file, 'defer')
  end

  def do_test(script, expected)
    File.open(@script_file, "w") { |file|
      file.print(script)
    }
    ruby = File.join(CONFIG['bindir'], 
		     CONFIG['ruby_install_name'])
    assert(system(ruby, @script_file) == false, "script should not succeed")
    assert($? == (expected << 8), "exit code not what is expected")
  end

  def test_reject
    do_test(@reject_script, 77)
  end

  def test_defer
    do_test(@defer_script, 75)
  end
end
