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

# A utility PushbackReader class that will eat whitepsace and
# normalize a leading From line.  E.g. if you have an input stream
# that begins with <tt>"\n\n>From foo@bar\n"</tt> it will eat the
# leading <tt>"\n\n>"</tt>.
#
# This is primarily useful for parsing input you know is a MIME entity
# with headers.
class RMail::Parser::SloppyStartReader < RMail::Parser::PushbackReader

  # Create a new sloppy start reader.
  def initialize(input)
    super
  end

  def read_chunk(size)          # :nodoc:
    chunk = standard_read_chunk(size)
    chunk.gsub!(/\A\n*>?/, '')

    unless chunk.empty?
      # If the chunk isn't empty, then we have reached the end of the
      # sloppy stuff we strip from the beginning of the stream.  So,
      # now behave just like our base class.
      def self.read_chunk(size)
        standard_read_chunk(size)
      end
    end

    chunk
  end
end

