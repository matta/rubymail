#!/usr/bin/env ruby
#--
#   Copyright (C) 2002 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

module Mail
  module Utils

    class << self

      # Return the given string unquoted if it is quoted.
      def unquote(str)
        if str =~ /\s*"(.*?([^\\]|\\\\))"/m
          $1.gsub(/\\(.)/, '\1')
        else
          str
        end
      end

      # Decode the given string as if it were a chunk of base64 data
      def base64_decode(str)
        str.unpack("m*").first
      end

      # Decode the given string as if it were a chunk of quoted
      # printable data
      def quoted_printable_decode(str)
        str.unpack("M*").first
      end

    end

  end
end

