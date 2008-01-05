#--
#   Copyright (C) 2002-2004 Matt Armstrong.  All rights reserved.
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
# Implements the RMail::Utils module.

module RMail

  # The RMail::Utils module is a collection of random utility methods
  # that are useful for dealing with email.
  module Utils

    class << self

      # Return the given string unquoted if it is quoted.
      # E.g. <tt>"foo"</tt> becomes +foo+.
      def unquote(str)
        if str =~ /\s*"(.*?([^\\]|\\\\))"/m
          $1.gsub(/\\(.)/, '\1')
        else
          str
        end
      end

      # Decode the given string as if it were a chunk of base64 data.
      def decode_base64(str)
        str.unpack("m*").first
      end

      # The old RubyMail 0.17 name.
      alias :base64_decode :decode_base64

      # Decode the given string as if it were a chunk of quoted
      # printable data.
      def decode_quoted_printable(str)
        str.unpack("M*").first
      end

      # The old RubyMail 0.17 name.
      alias :quoted_printable_decode :decode_quoted_printable

      # Decode the given string as if it were a chunk of uuencoded
      # data.
      def decode_uuencoded(str)
        uudecoding = false
        accum = ''
        str.each_line do |uu_line|
          if uudecoding
            break if /^end\b/i.match(uu_line)
            accum << uu_line.unpack("u*").first
          else
            next unless /^begin\b/i.match(uu_line)
            uudecoding = true
          end
        end
        accum
      end

    end
  end
end
