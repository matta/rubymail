#!/usr/bin/env ruby
#--
#   Copyright (C) 2002 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

require 'tests/testbase'
require 'rmail/parser/multipart'

class TestRMailParserMultipart < TestBase

  # FIXME: TODO
  # - test \n -vs- \r\n -vs \r end of line characters

  def parse_multipart(file, boundary, chunk_size, expected_results)
    data_as_file(file) { |f|
      parser = RMail::Parser::MultipartReader.new(f, boundary)

      results = []
      chunk = nil
      loop {
        temp = parser.read(chunk_size)
        if temp
          chunk ||= ''
          chunk << temp
        else
          if chunk
            results << [ chunk, parser.preamble?, parser.epilogue? ]
            chunk = nil
          end
          unless parser.next_part
            break
          end
        end
      }

      if expected_results != results
        puts
        p expected_results
        p results
      end
      assert_equal(expected_results, results,
                   "\nfile #{file}\nchunk_size #{chunk_size}\n")
    }
  end

  def for_all_chunk_sizes(file, boundary, expected_results)
    1.upto(File.stat(data_filename(file)).size) { |size|
      parse_multipart(file, boundary, size, expected_results)
    }
  end

  def test_basic
    data_as_file('parser.multipart.basic') { |f|
      p = RMail::Parser::MultipartReader.new(f, "boundary")

      assert(p.preamble?)
      assert(!p.epilogue?)
      assert_equal("preamble1\npreamble2", p.read)
      assert(p.preamble?)
      assert(!p.epilogue?)
      assert_nil(p.read)

      assert(p.next_part)
      assert(!p.preamble?)
      assert(!p.epilogue?)

      assert_equal("part1-1\npart1-2", p.read)
      assert(!p.preamble?)
      assert(!p.epilogue?)
      assert_nil(p.read)

      assert(p.next_part)
      assert(!p.preamble?)
      assert(!p.epilogue?)

      assert_equal("part2-1\npart2-2", p.read)
      assert(!p.preamble?)
      assert(!p.epilogue?)
      assert_nil(p.read)

      assert(p.next_part)
      assert(!p.preamble?)
      assert(p.epilogue?)

      assert_equal("epilogue1\nepilogue2\n", p.read)
      assert(!p.preamble?)
      assert(p.epilogue?)
      assert_nil(p.read)

      assert(!p.next_part)
    }

    for_all_chunk_sizes('parser.multipart.basic', 'boundary',
                        [ [ "preamble1\npreamble2", true, false ],
                          [ "part1-1\npart1-2", false, false ],
                          [ "part2-1\npart2-2", false, false ],
                          [ "epilogue1\nepilogue2\n", false, true ] ])
  end

  def test_multipart_preamble
    for_all_chunk_sizes('parser.multipart.preamble', 'X',
                        [ [ "Preamble, trailing newline ->\n",
                            true, false ],
                          [ "Epilogue, trailing newline ->\n",
                            false, true ] ])
  end

  def test_multipart_epilogue
    for_all_chunk_sizes('parser.multipart.epilogue', 'X',
                        [ [ "Part data.", false, false ] ])
  end

  def test_s_new
    data_as_file('parser.multipart.basic') { |f|
      p = RMail::Parser::MultipartReader.new(f, "foo")
      assert_kind_of(RMail::Parser::MultipartReader, p)
    }
  end

end

