#!/usr/bin/env ruby
#
#   Copyright (C) 2001, 2002 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

$LOAD_PATH.unshift(".")		# get our stuff first
#$LOAD_PATH.unshift("/home/matt/cvs/ruby-lang/rough/lib/testunit/packages/runit-compat/lib")
#$LOAD_PATH.unshift("/home/matt/cvs/ruby-lang/rough/lib/testunit/packages/testunit/lib")

Dir['tests/test*.rb'].each {|f|
  require f
}
