#!/usr/bin/env ruby
#
#   Copyright (c) 2001 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

#$LOAD_PATH.unshift("/home/matt/Lapidary/lib")
$LOAD_PATH.unshift(".")

require 'runit/cui/testrunner'
require 'tests/testall'

RUNIT::CUI::TestRunner.run(TestAll.suite)
