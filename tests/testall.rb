#!/usr/bin/env ruby
#
#   Copyright (c) 2001 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

require 'runit/testsuite'

require 'tests/testheader'
require 'tests/testmessage'
require 'tests/testdeliver'
require 'tests/testlda'
require 'tests/testaddress'

class TestAll
  def TestAll.suite
    suite = RUNIT::TestSuite.new
    ObjectSpace.each_object(Class) do |k|
      if k.ancestors.include?(RUNIT::TestCase)
	suite.add_test(k.suite)
      end
    end
    suite
  end
end


