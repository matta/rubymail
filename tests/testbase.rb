#!/usr/bin/env ruby
#
#   Copyright (c) 2001 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

# Base for all the test cases, providing a default setup and teardown

require 'runit/testcase'
require 'rbconfig.rb'

class TestBase < RUNIT::TestCase
  include Config

  attr_reader :scratch_dir
  attr_reader :ruby_bin

  # NoMethodError was introduced in ruby 1.7
  NO_METHOD_ERROR = if RUBY_VERSION >= "1.7"
		      NoMethodError
		    else
		      NameError
		    end

  def cleandir(dir)
    if FileTest.directory?(dir)
      Dir.foreach(dir) { |f|
	file = File.join(dir, f)
	if FileTest.file?(file)
	  File.unlink(file)
	end
      }
    end
  end

  def setup
    @scratch_dir = "_scratch_" + name
    @ruby_bin = File.join(CONFIG['bindir'], 
			  CONFIG['ruby_install_name'])

    cleandir(@scratch_dir)
    Dir.rmdir(@scratch_dir) if FileTest.directory?(@scratch_dir)
    Dir.mkdir(@scratch_dir) unless FileTest.directory?(@scratch_dir)
  end

  def teardown
    unless $!
      cleandir(@scratch_dir)
      Dir.rmdir(@scratch_dir) if FileTest.directory?(@scratch_dir)
    end
  end
end
