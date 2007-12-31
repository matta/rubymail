#!/usr/bin/env ruby
#--
#   Copyright (c) 2004 Matt Armstrong.  All rights reserved.
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


require 'rmail/parser/pushbackreader'
require 'rmail/superstring'

# A PushbackReader that accumulates everything it parses.
class RMail::Parser::AccumulateReader < RMail::Parser::PushbackReader

  # Create an AccumulateReader
  def initialize(input)
    super
    @superstring = RMail::Superstring.new
  end

  # Return the accumulated data.  This consists of the concatenation
  # of all chunks read from #read and #read_chunk, minus any string
  # passed to #pushback.
  def accumulated
    @superstring.substring(0, @superstring.length)
  end

  def read_chunk(size)
    chunk = super
    @superstring << chunk if chunk
    chunk
  end

  def pushback(string)
    super
    @superstring.truncate(@superstring.length - string.length)
  end

  def pos
    @superstring.length
  end

  def substring(start, length)
    @superstring.substring(start, length)
  end

end

