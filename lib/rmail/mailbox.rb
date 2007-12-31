#!/usr/bin/env ruby
#--
#   Copyright (c) 2002, 2003 Matt Armstrong.  All rights reserved.
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
# Implements the RMail::Mailbox module.

module RMail

  # The RMail::Mailbox module contains a few methods that are useful
  # for working with mailboxes.
  module Mailbox

    class << self

      # Parse a Unix mbox style mailbox.  These mailboxes searate
      # individual messages with a line beginning with the string
      # "From ".
      #
      # If a block is given, yields to the block with the raw message
      # (a string), otherwise an array of raw message strings is
      # returned.
      def parse_mbox(input, line_separator = $/)
        require 'rmail/mailbox/mboxreader'
        retval = []
        RMail::Mailbox::MBoxReader.new(input, line_separator).each_message {
          |reader|
          raw_message = reader.read(nil)
          if block_given?
            yield raw_message
          else
            retval << raw_message
          end
        }
        return block_given? ? nil : retval
      end

    end
  end
end
