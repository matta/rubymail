#!/usr/bin/env ruby
#--
#   Copyright (C) 2001, 2002, 2003, 2007 Matt Armstrong.  All rights reserved.
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

# Base for all the test cases, providing a default setup and teardown

require 'test/unit'
require 'rbconfig.rb'
require 'tempfile'
require 'find'
require 'fileutils'

begin
  require 'pp'
rescue LoadError
end

class TestBase < Test::Unit::TestCase
  include RbConfig

  attr_reader :scratch_dir

  def test_nothing
    assert(true)  # Appease Test::Unit
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
    unless regexp.kind_of?(Regexp)
      regexp = Regexp.new(regexp)
    end
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
	else
	  File.delete(f)
	end
      }
    end
  end

  def setup
    @scratch_dir = File.join(Dir.getwd, "_scratch_" + name)
    @data_dir = File.join(Dir.getwd, "test", "data")
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
    unless name =~ %r{^/}
      name = data_filename(name)
    end
    File.open(name) { |f|
      yield f
    }
  rescue Errno::ENOENT
    flunk("data file #{name.inspect} does not exist")
  end

  def data_as_string(name)
    data_as_file(name) { |f|
      f.read
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

  def scratch_file_write(name)
    name = scratch_filename(name)
    File.open(name, 'w') { |f|
      yield f
    }
  end

  def teardown
    unless $! || ((defined? passed?) && !passed?)
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
