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
      loop {
        chunk = nil
        while temp = parser.read(chunk_size)
          chunk ||= ''
          chunk << temp
        end

        results << [ chunk, parser.preamble?, parser.epilogue? ]

        unless parser.next_part
          break
        end
      }

      if expected_results != results
        puts "\nfailure for chunks size #{chunk_size.to_s}"
        pp expected_results
        pp results
      end
      assert_equal(expected_results, results,
                   "\nfile #{file}\nchunk_size #{chunk_size}\n")
    }
  end

  def for_all_chunk_sizes(file, boundary, expected_results)
    1.upto(File.stat(data_filename(file)).size + 10) { |size|
      parse_multipart(file, boundary, size, expected_results)
    }
  end


  def test_basic
    for_all_chunk_sizes('parser.multipart.basic', 'X',
                        [ [ "p1\np2", true, false ],
                          [ "\npt1-1\npt1-2", false, false ],
                          [ "\npt2-1\npt2-2", false, false ],
                          [ "\ne1\ne2\n", false, true ] ])
  end

  def test_basic2
    for_all_chunk_sizes('parser.multipart.basic2', 'X',
                        [ [ nil, true, false ],
                          [ nil, false, false ],
                          [ nil, false, false ],
                          [ "\n", false, true ] ])
  end

  def test_basic3
    for_all_chunk_sizes('parser.multipart.basic3', 'boundary',
                        [ [ nil, true, false ],
                          [ "\n", false, true ] ])
  end

  def test_multipart_preamble
    for_all_chunk_sizes('parser.multipart.preamble', 'X',
                        [ [ "Preamble, trailing newline ->\n",
                            true, false ],
                          [ "\nEpilogue, trailing newline ->\n",
                            false, true ] ])
  end

  def test_multipart_epilogue
    for_all_chunk_sizes('parser.multipart.epilogue', 'X',
                        [ [ nil, true, false ],
                          [ "\nPart data.", false, false ],
                          [ "\n", false, true ] ])
  end

  def test_s_new
    data_as_file('parser.multipart.basic') { |f|
      p = RMail::Parser::MultipartReader.new(f, "foo")
      assert_kind_of(RMail::Parser::MultipartReader, p)
    }
  end

end

