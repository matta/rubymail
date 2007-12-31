#!/usr/bin/env ruby
#--
#   Copyright (c) 2004 Matt Armstrong.  All rights reserved.
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

require 'test/unit/testcase'
require 'pp'

ARGV.each { |path|
  load path
}

def find_test_cases
  found = []

  ObjectSpace.each_object(Class) { |klass|
    if (Test::Unit::TestCase > klass)
      found << klass
    end
  }

  found
end

class GetClassError < StandardError; end

def get_class(name)
  Module.const_get(name.to_s.intern)
rescue NameError
  raise GetClassError, "can not find module/class #{name}"
end

def get_tested_class(tc_name)
  name = tc_name.to_s.gsub(/(^|::)TC_/, '\1')
  get_class(name)
rescue GetClassError
  unless name =~ /::/
    candidates = []
    ObjectSpace.each_object(Module) { |klass|
      begin
        candidates << klass.const_get(name)
      rescue NameError
      end
    }
    case candidates.length
    when 0
    when 1
      return candidates.first
    else
      puts "# WARNING: #{tc_name} resolves ambiguously to " +
        "#{candidates.inspect}."
    end
  end
  puts "# WARNING: #{tc_name} cannot find tested class."
end

SPECIAL_METHODS = {
  '+'   => 'PLUS',
  '-'   => 'MINUS',
  '*'   => 'MUL',
  '/'   => 'DIV',
  '%'   => 'MOD',
  '**'  => 'POW',
  '&'   => 'AND',
  '|'   => 'OR',
  '^'   => 'XOR',
  '~'   => 'REV',
  '<<'  => 'LSHIFT',
  '>>'  => 'RSHIFT',
  '<'   => 'LT',
  '<='  => 'LE',
  '>'   => 'GT',
  '>='  => 'GE',
  '<=>' => 'CMP',
  '=='  => 'EQUAL',
  '===' => 'CASE_EQUAL',
  '=~'  => 'MATCH',
  '[]'  => 'AREF',
  '[]=' => 'ASET',
  '-@'  => 'MINUS_AT',
  '+@'  => 'PLUS_AT'
}

def test_method_name(method)
  if SPECIAL_METHODS.include?(method)
    "test_#{SPECIAL_METHODS[method]}"
  else
    method = method.sub(/=$/, '_SET')
    "test_#{method}"
  end
end

def adorned_test_method_name(method)
  if SPECIAL_METHODS.include?(method)
    "test_#{SPECIAL_METHODS[method]} # '#{method}'"
  elsif method =~ /=$/
    method_set = method.sub(/=$/, '_SET')
    "test_#{method_set} # '#{method}'"
  else
    "test_#{method}"
  end
end

def fill_out_tests(tested, test_case)

  # Odd case that occurs when dealing with subclasses of
  # Test::Unit::TestCase
  if tested == test_case
    return
  end

  puts "# Create #{tested} tests missing from #{test_case}"

  methods = tested.public_instance_methods(false)
  test_methods = test_case.public_instance_methods(false)

  methods = methods.delete_if { |method|
    test_methods.include?(test_method_name(method))
  }

  unless methods.empty?
    puts "\nclass #{test_case}"
    methods.sort.each { |method|
      puts "  def #{adorned_test_method_name(method)}"
      puts "    flunk 'test not implemented'"
      puts "  end"
      puts
    }
    print "end\n\n"
  end
end

def main
  test_cases = find_test_cases
  map_to_tested = {}
  map_to_case = {}

  test_cases.each { |test_case|
    tested = get_tested_class(test_case)
    map_to_tested[test_case] = tested
    map_to_case[tested] = test_case
  }

  test_cases.each { |test_case|
    if tested = get_tested_class(test_case)
      fill_out_tests(tested, test_case)
    else
      puts "# WARNING: skipping analysis of #{test_case}"
    end
  }
  exit
end

main
