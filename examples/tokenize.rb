#!/usr/bin/env ruby
#--
#   Copyright (c) 2003 Matt Armstrong.  All rights reserved.
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
#++
# = Tokenization of an Email
#
# This script "tokenizes" an email seen on stdin into a set of tokens
# printed to stdout.  This is the same kind of process used by many
# "Bayesian" SPAM filters that are popular these days (in early 2003).
#

require 'rubymail/parser'
include RubyMail

class TokenizingHandler < Parser::StreamHandler
  def initialize
    @tokens = Hash.new(0)
    @chunk = nil
  end

  def process_chunk(chunk)
    if @chunk
      @chunk << chunk
    else
      @chunk = chunk
    end
  end

  def finish_chunk
    if @chunk
      @chunk.scan(/\w+/) { |w|
        @tokens[w] += 1 if w.length >= 3
      }
    end
  end

  def header_field(field, name, value)
  end

  def body_chunk(chunk)
    process_chunk(chunk)
  end

  def body_end
    finish_chunk
  end

  def preamble_chunk(chunk)
    process_chunk(chunk)
  end

  def preamble_end
    finish_chunk
  end

  def part_begin
    finish_chunk
  end

  def epilogue_chunk(chunk)
    process_chunk(chunk)
  end

  def epilogue_end
    finish_chunk
  end

  def print_tokens(io)
    @tokens.keys.sort.each { |t|
      io.puts "%3d %s" % [ @tokens[t], t.inspect ]
    }
  end

end


handler = TokenizingHandler.new
StreamParser.parse(STDIN, handler)
handler.print_tokens(STDOUT)
