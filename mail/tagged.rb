#!/usr/bin/env ruby
=begin
   Copyright (C) 2002 Matt Armstrong.  All rights reserved.

   Permission is granted for use, copying, modification, distribution,
   and distribution of modified versions of this work as long as the
   above copyright notice is included.
=end

require 'mail/address'
require 'hmac-sha1'

module Mail
  class AddressTagger

    attr :key, true
    attr :delimiter, true
    attr :strength, true

    def initialize(key, delimiter, strength)
      @key = key
      @delimiter = delimiter
      @strength = strength
    end

    # expires is the absolute time this dated address will expire.
    # E.g. Time.now + (60 * 60 * 24 * age)
    def dated(address, expires)
      tag_address(address, expires.strftime("%Y%m%d%H%S"), 'd')
    end

    def keyword(address, keyword)
      tag_address(address, keyword.downcase.gsub(/[^\w\d]/, '_'), 'k')
    end

    # Returns true if an address verifies.  I.e. that the text portion
    # of the tag matches its HMAC.  Throws an ArgumentError if the
    # address isn't tagged at all.
    def verify(address)
      text, type, hmac = tag_parts(address)
      raise ArgumentError, "address not tagged" unless hmac
      hmac_digest(text, hmac.length / 2) == hmac
    end

    private

    def tag_address(address, text, type)
      address = address.dup
      cookie = hmac_digest(text, @strength)
      address.local = format("%s%s%s.%s.%s", address.local,
                             delimiter, text, type, cookie)
      address
    end

    def hmac_digest(text, strength)
      HMAC::SHA1.digest(@key, text)[0...strength].unpack("H*")[0]
    end

    def tag_parts(address)
      d = Regexp.quote(@delimiter)
      if address.local =~ /#{d}([\w\d]+)\.([\w]+)\.([0-9a-h]+)$/i
            [$1, $2, $3]
          end
      end
    end
end
