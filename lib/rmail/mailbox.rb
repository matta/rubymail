#!/usr/bin/env ruby
#--
#   Copyright (c) 2002, 2003 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

module RMail
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
