#!/usr/bin/env ruby
#--
#   Copyright (C) 2002, 2004 Matt Armstrong.  All rights reserved.
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

require 'test/testbase'
require 'rmail/parser/multipart'

class TestRMailParserMultipart < TestBase

  # FIXME: TODO
  # - test \n -vs- \r\n -vs \r end of line characters

  def parse_multipart(filename, boundary, chunk_size, expected_results)
    assembled = nil

    data_as_file(filename) { |f|
      parser = RMail::Parser::MultipartReader.new(f, boundary)
      parser.chunk_size = chunk_size

      results = []
      loop {
        chunk = parser.read(nil)
        puts "test: got part #{chunk.inspect}" if $DEBUG
        delimiter = parser.delimiter
        puts "test: got delimiter #{delimiter.inspect}" if $DEBUG
        if chunk
          assembled ||= ''
          assembled << chunk
        end
        if delimiter
          assembled ||= ''
          assembled << delimiter
        end
        results << [
          chunk,
          parser.preamble?,
          parser.epilogue?,
          delimiter
        ]
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
                   "\nfile #{filename}\nchunk_size #{chunk_size}\n")
    }

    filedata = data_as_file(filename) { |f|
      f.read(nil)
    }
    filedata = nil if filedata.empty?

    assert_equal(filedata, assembled,
                 "data loss while reassembling file data")
  end

  def for_all_chunk_sizes(filename, boundary, expected_results)
    size = File.stat(data_filename(filename)).size
    (size + 10).downto(1) { |chunk_size|
      parse_multipart(filename, boundary, chunk_size, expected_results)
    }
  end

  def test_multipart_data_01
    for_all_chunk_sizes('multipart/data.1', 'aa',
                        [ [ "preamble", true, false, "\n--aa\n" ],
                          [ "part1", false, false, "\n--aa--\n" ],
                          [ "epilogue\n", false, true, nil ] ])
  end
  def test_multipart_data_02
    for_all_chunk_sizes('multipart/data.2', 'aa',
                        [ [ nil, true, false, "\n--aa\n" ],
                          [ nil, false, false, "\n--aa--\n" ],
                          [ "\n", false, true, nil ] ])
  end
  def test_multipart_data_03
    for_all_chunk_sizes('multipart/data.3', 'aa',
                        [ [ nil, true, false, "--aa\n" ],
                          [ nil, false, false, "--aa--\n" ],
                          [ "", false, true, nil ] ])
  end
  def test_multipart_data_04
    for_all_chunk_sizes('multipart/data.4', 'aa',
                        [ [ "preamble", true, false, "\n--aa--\n" ],
                          [ "epilogue\n", false, true, nil ] ])
  end
  def test_multipart_data_05
    for_all_chunk_sizes('multipart/data.5', 'aa',
                        [ [ nil, true, false, "--aa--\n" ],
                          [ "", false, true, nil ] ])
  end
  def test_multipart_data_06
    for_all_chunk_sizes('multipart/data.6', 'aa',
                        [ [ nil, true, false, "\n--aa--\n" ],
                          [ "", false, true, nil ] ])
  end
  def test_multipart_data_07
    for_all_chunk_sizes('multipart/data.7', 'aa',
                        [ [ "preamble\n", true, false, "\n--aa--\n" ],
                          [ "", false, true, nil ] ])
  end
  def test_multipart_data_08
    for_all_chunk_sizes('multipart/data.8', 'aa',
                        [ [ "preamble", true, false, "\n--aa\n" ],
                          [ "part1", false, false, "\n--aa--\n" ],
                          [ "epilogue", false, true, nil ] ])
  end
  def test_multipart_data_09
    for_all_chunk_sizes('multipart/data.9', 'aa',
                        [ [ nil, true, false, "\n--aa\n" ],
                          [ nil, false, false, "\n--aa--" ],
                          [ "", false, true, nil ] ])
  end
  def test_multipart_data_10
    for_all_chunk_sizes('multipart/data.10', 'aa',
                        [ [ nil, true, false, "--aa--" ],
                          [ "", false, true, nil ] ])
  end
  def test_multipart_data_11
    for_all_chunk_sizes('multipart/data.11', 'aa',
                        [ [ "preamble", true, false, "\n--aa\t\n" ],
                          [ "part1", false, false, "\n--aa \n" ],
                          [ "part2", false, false, "\n--aa \t \t\n" ],
                          [ "part3", false, false, "\n--aa-- \n" ],
                          [ "epilogue\n", false, true, nil ] ])
  end
  def test_multipart_data_12
    # The following from RFC2046 indicates that a delimiter existing
    # as the prefix of a line is sufficient for the line to be
    # considered a delimiter -- even if there is stuff after the
    # boundary:
    #
    #    NOTE TO IMPLEMENTORS: Boundary string comparisons must
    #    compare the boundary value with the beginning of each
    #    candidate line.  An exact match of the entire candidate line
    #    is not required; it is sufficient that the boundary appear in
    #    its entirety following the CRLF.
    #
    # However, messages in the field do not seem to comply with this
    # (namely, Eudora), so we parse more strictly.
    for_all_chunk_sizes('multipart/data.12', 'aa',
                        [[ "preamble\n--aaZ\npart1\n--aa notignored\npart2\n--aa \t \tnotignored\npart3\n--aa--notignored\nepilogue\n",
                            true,
                            false,
                            nil ]])
  end
  def test_multipart_data_13
    for_all_chunk_sizes('multipart/data.13', 'aa',
                        [ [ "preamble", true, false, "\n--aa\n" ],
                          [ "part1\n", false, false, nil ] ])
  end
  def test_multipart_data_14
    for_all_chunk_sizes('multipart/data.14', 'aa',
                        [ [ "preamble", true, false, "\n--aa\n" ],
                          [ "part1", false, false, nil ] ])
  end
  def test_multipart_data_15
    for_all_chunk_sizes('multipart/data.15', 'aa',
                        [ [ "preamble\nline1\nline2\n", true, false, nil ] ])
  end
  def test_multipart_data_16
    for_all_chunk_sizes('multipart/data.16', 'aa',
                        [ [ "preamble\nline1\nline2", true, false, nil ] ])
  end
  def test_multipart_data_17
    for_all_chunk_sizes('multipart/data.17', 'aa',
                        [ [ nil, true, false, nil ] ])
  end

  def test_s_new
    data_as_file('multipart/data.1') { |f|
      p = RMail::Parser::MultipartReader.new(f, "foo")
      assert_kind_of(RMail::Parser::MultipartReader, p)
    }
  end

end
