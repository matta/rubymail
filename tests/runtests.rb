#!/usr/bin/env ruby
#
#   Copyright (C) 2001, 2002, 2003 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

fail "must run this script directly" unless __FILE__ == $0
path = File.expand_path(File.join(File.dirname($0), '..', 'lib'))
puts "Prepending #{path} to the $LOAD_PATH"
$LOAD_PATH.unshift(path)        # get our stuff first

Dir['tests/test*.rb'].each {|f|
  require f
}
