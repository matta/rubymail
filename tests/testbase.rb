#!/usr/bin/env ruby
=begin
   Copyright (C) 2001, 2002 Matt Armstrong.  All rights reserved.

   Permission is granted for use, copying, modification, distribution,
   and distribution of modified versions of this work as long as the
   above copyright notice is included.
=end

# Base for all the test cases, providing a default setup and teardown

require 'rubyunit'
require 'rbconfig.rb'
require 'tempfile'
require 'find'

begin
  require 'pp'
rescue LoadError
end

class TestBase < RUNIT::TestCase
  include Config

  attr_reader :scratch_dir

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
    @scratch_dir = File.join(Dir.getwd, "_scratch_" + name)
    @data_dir = File.join(Dir.getwd, "tests", "data")
    @scratch_hash = {}

    cleandir(@scratch_dir)
    Dir.rmdir(@scratch_dir) if FileTest.directory?(@scratch_dir)
    Dir.mkdir(@scratch_dir) unless FileTest.directory?(@scratch_dir)
  end

  def ruby_program
    File.join(CONFIG['bindir'], CONFIG['ruby_install_name'])
  end

  def data_filename(name)
    File.join(@data_dir, name)
  end

  def data_as_file(name)
    File.open(data_filename(name)) { |f|
      yield f
    }
  end

  def scratch_filename(name)
    if @scratch_hash.key?(name)
      temp = @scratch_hash[name]
      temp = temp.succ
      @scratch_hash[name] = name = temp
    else
      temp = name.dup
      temp << '.0' unless temp =~ /\.\d+$/
      @scratch_hash[name] = temp
    end
    File.join(@scratch_dir, name)
  end

  def teardown
    unless $!
      cleandir(@scratch_dir)
      Dir.rmdir(@scratch_dir) if FileTest.directory?(@scratch_dir)
    end
  end

  def call_fails(arg, &block)
    begin
      yield arg
    rescue Exception
      return true
    end
    return false
  end

  # if a random string failes, run it through this function to find the
  # shortest fail case
  def find_shortest_failure(str, &block)
    unless call_fails(str, &block)
      raise "hey, the input didn't fail!"
    else
      # Chop off stuff from the beginning and then the end
      # until it stops failing
      bad = str
      0.upto(bad.length) {|index|
	bad.length.downto(1) {|length|
	  begin
	    loop {
	      s = bad.dup
	      s[index,length] = ''
	      break if bad == s
	      break unless call_fails(s, &block)
	      bad = s
	    }
	  rescue IndexError
	    break
	  end
	}
      }
      raise "shortest failure is #{bad.inspect}"
    end
  end

end
