#!/usr/bin/env ruby
#--
#   Copyright (c) 2002 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

module RMail
  class Header

    class Field

      # fixme, document methadology for this (RFC2822)
      EXTRACT_FIELD_NAME_RE = /\A([^\x00-\x1f\x7f-\xff :]+):\s*/o

      def initialize(name, value = nil)
        if value
          @name = Field.name_strip(name.to_str).freeze
          @value = Field.value_strip(value.to_str).freeze
          @raw = nil
        else
          @raw = name.to_str.freeze
          if @raw =~ EXTRACT_FIELD_NAME_RE
            @name = $1
            @value = $'.chomp.freeze
          else
            @name = "".freeze
            @value = Field.value_strip(@raw).freeze
          end
        end
      end

      def name
        @name
      end

      def value
        @value
      end

      def raw
        @raw
      end

      def ==(other)
        other.kind_of?(self.class) &&
          @name.downcase == other.name.downcase &&
          @value == other.value
      end

      def Field.name_canonicalize(name)
        name_strip(name.to_str).downcase
      end

      private

      def Field.name_strip(name)
        name.sub(/\s*:.*/, '')
      end

      def Field.value_strip(value)
        if value.frozen?
          value = value.dup
        end
        value.strip!
        value
      end

    end

  end
end
