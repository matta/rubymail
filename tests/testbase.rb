#!/usr/bin/env ruby
#
#   Copyright (c) 2001 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

# Base for all the test cases, providing a default setup and teardown

require 'rubyunit'
require 'rbconfig.rb'
require 'tempfile'
require 'find'

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

  # Print a string to a temporary file and return the file opened.
  # This lets you have some test data in a string, but access it with
  # a file.
  def string_as_file(string, strip_whitespace = true)
    if strip_whitespace
      temp = ""
      string.each_line { |line|
	temp += line.sub(/^[ \t]+/, '')
      }
      string = temp
    end
    file = Tempfile.new("ruby.string_as_file.")
    begin
      file.print(string)
      file.close()
      file.open()
      yield file
    ensure
      file.close(true)
    end
  end

  # Return true if the given file contains a line matching regexp
  def file_contains(filename, regexp)
    detected = nil
    File.open(filename) { |f|
      detected = f.detect { |line|
	line =~ regexp
      }
    }
    ! detected.nil?
  end

  # Deletes everything in directory +dir+, including any
  # subdirectories
  def cleandir(dir)
    if FileTest.directory?(dir)
      files = []
      Find.find(dir) { |f|
	files.push(f)
      }
      files.shift		# get rid of 'dir'
      files.reverse_each { |f|
	if FileTest.directory?(f)
	  Dir.delete(f)
	elsif FileTest.file?(f)
	  File.delete(f)
	else
	  raise "can't delete #{f} " + FileTest.directory?(f).inspect +
	  FileTest.file?(f).inspect
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

  def scratch_filename(name)
    scratch = File.join(@scratch_dir, name)
    assert_equal(false, test(?e, scratch),
		 "scratch file #{scratch} already exists")
    scratch
  end

  def teardown
    unless $!
      cleandir(@scratch_dir)
      Dir.rmdir(@scratch_dir) if FileTest.directory?(@scratch_dir)
    end
  end
end
