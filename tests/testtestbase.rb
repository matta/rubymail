#!/usr/bin/env ruby
#
#   Copyright (c) 2001 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

# Test the TestBase class itself

require 'rubyunit'
require 'tests/testbase.rb'

class TestTestBase < TestBase

  def test_cleandir
    Dir.mkdir("_testdir_")
    Dir.mkdir("_testdir_/testsubdir")
    File.open("_testdir_/testfile", "w") { |file|
      file.puts "some data"
    }
    File.open("_testdir_/testsubdir/testfile", "w") { |file|
      file.puts "some data"
    }
    assert(test(?e, "_testdir_"))
    assert(test(?e, "_testdir_/testsubdir"))
    assert(test(?e, "_testdir_/testsubdir/testfile"))
    assert(test(?e, "_testdir_/testfile"))
    cleandir("_testdir_")
    assert(test(?e, "_testdir_"))
    assert(!test(?e, "_testdir_/testsubdir"))
    assert(!test(?e, "_testdir_/testsubdir/testfile"))
    assert(!test(?e, "_testdir_/testfile"))
    assert_equal(0, Dir.delete('_testdir_'))
  end

  def test_file_contains
    scratch = scratch_filename("file_contains")
    File.open(scratch, "w") { |f|
      f.puts "contains AAA"
      f.puts "contains BBB"
    }
    assert(file_contains(scratch, /BBB/))
    assert(file_contains(scratch, "AAA"))
    assert(file_contains(scratch, /contains AAA/))
    assert(file_contains(scratch, "contains BBB"))
    assert_equal(false, file_contains(scratch, /contains CCC/))
    assert_equal(false, file_contains(scratch, "contains CCC"))
  end

  def test_ruby_bin
    assert_not_nil(ruby_bin)
    assert_kind_of(String, ruby_bin)
  end

  def verify_scratch_dir_name(dir)
    assert_match(/scratch.*TestTestBase.*test/, dir)
  end

  def test_scratch_dir
    assert_not_nil(scratch_dir)
    assert_kind_of(String, scratch_dir)
    verify_scratch_dir_name(scratch_dir)
  end

  def test_scratch_filename
    name = scratch_filename("foobar")
    assert_kind_of(String, name)
    verify_scratch_dir_name(File.dirname(name))
    assert_equal("foobar", File.basename(name))
  end

  def test_string_as_file
    string = "yo\nman\n"
    string_as_file(string) { |f|
      assert_equal(string, f.readlines.join(''))
    }
    string2 = "   yo\n   man\n"
    string_as_file(string2) { |f|
      assert_equal("yo\nman\n", f.readlines.join(''))
    }
    string_as_file(string2, false) { |f|
      assert_equal(string2, f.readlines.join(''))
    }
  end

end

