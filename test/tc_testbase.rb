#!/usr/bin/env ruby
#--
#   Copyright (C) 2001, 2002, 2004 Matt Armstrong.  All rights reserved.
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

# Test the TestBase class itself

require 'test/testbase.rb'

class TC_TestBase < TestBase

  def test_setup
    assert(FileTest.directory?(@scratch_dir))
    assert(FileTest.directory?(@data_dir))
  end

  def test_teardown
    test_setup
    teardown
    assert(!FileTest.directory?(@scratch_dir))
  end

  def test_call_raises
    failed = call_raises("arg") { |arg|
      raise if arg == arg
    }
    assert(failed)

    failed = call_raises("arg") { |arg|
      raise if arg != arg
    }
    assert(true)
  end

  def test_data_as_file
    data_as_file("test_data_as_file") { |f|
      assert_kind_of(File, f)
      assert_equal("Some\nData\n", f.read)
    }
  end

  def test_data_as_string
    data_as_string("test_data_as_file") { |s|
      assert_equal("Some\nData\n", s)
    }
  end

  def test_data_filename
    assert_equal(@data_dir, File.dirname(data_filename("foo")))
    assert_equal("foo", File.basename(data_filename("foo")))
  end

  def test_extra_load_paths
    # Leaving this untested.
  end

  def test_find_shortest_failure
    # Leaving this untested.
  end

  def test_platform_is_windows_filesystem
    # Leaving this untested.
  end

  def test_platform_is_windows_native
    # Leaving this untested.
  end

  def test_platform_null_file
    # Leaving this untested.
  end

  def test_test_nothing
    # Leaving this untested.
  end

  def test_with_string_in_file
    text = "A string in a file!\n"
    name = ''
    with_string_in_file(text, "template") { |name|
      assert_equal(@scratch_dir, File.dirname(name))
      FileTest::exists?(name)
    }
    FileTest::exists?(name)
  end

  def test_string_vary_eol
    e = assert_raise(ArgumentError) {
      string_vary_eol("foo\rbar")
    }
    assert_equal('string contains \r characters', e.message)

    string = "abcd\nefgh\n"

    results = [ "abcd\nefgh\n", "abcd\r\nefgh\r\n" ]
    string_vary_eol(string) { |s|
      assert_equal(results.shift, s, "unexpected string_var_eol variant")
    }
  end

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

  def test_ruby_program
    assert_not_nil(ruby_program)
    assert_kind_of(String, ruby_program)
  end

  def verify_scratch_dir_name(dir)
    assert_match(/scratch.*TC_TestBase/, dir)
  end

  def test_name
    assert_match(/\btest_name\b/, name)
    assert_match(/\bTC_TestBase\b/, name)
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

    name = scratch_filename("foobar")
    assert_kind_of(String, name)
    verify_scratch_dir_name(File.dirname(name))
    assert_equal("foobar.1", File.basename(name))
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

