#!/usr/bin/env ruby
=begin
   Copyright (C) 2002 Matt Armstrong.  All rights reserved.

   Permission is granted for use, copying, modification,
   distribution, and distribution of modified versions of this work
   as long as the above copyright notice is included.
=end

require 'tests/testbase'
require 'mail/tagged'

class TestMail__AddressTagger < TestBase

  def address(s)
    Mail::Address.parse(s)[0]
  end

  def test_tag_dated
    a1 = address("Bob Smith <bob@example.net>")
    t = Mail::AddressTagger.new("the key", "+", 10)
    a2 = t.dated(a1, Time.now + 60)
    assert_equal("bob", a1.local)
    assert_match(/^bob\+\d{12}\.d\.[\da-h]{20}$/, a2.local)

    # Test varying the strength
    a1 = address("Bob Smith <bob@example.net>")
    t = Mail::AddressTagger.new("the key", "+", 3)
    a2 = t.dated(a1, Time.now + 60)
    assert_equal("bob", a1.local)
    assert_match(/^bob\+\d{12}\.d\.[\da-h]{6}$/, a2.local)
  end

  def test_tag_keyword
    a1 = address("Bob Smith <bob@example.net>")
    t = Mail::AddressTagger.new("the key", "+", 10)
    a2 = t.keyword(a1, "the keyword")
    assert_equal("bob", a1.local)
    assert_match(/^bob\+the_keyword\.k\.[\da-h]{20}$/, a2.local)

    # Test varying the strength
    a1 = address("Bob Smith <bob@example.net>")
    t = Mail::AddressTagger.new("the key", "+", 3)
    a2 = t.keyword(a1, "the keyword")
    assert_equal("bob", a1.local)
    assert_match(/^bob\+the_keyword\.k\.[\da-h]{6}$/, a2.local)
  end

  def test_verify
    t = Mail::AddressTagger.new("the key", "+", 7)

    assert(t.verify(address("bob+the_keyword.k.9ac20a3ca7a6fb@example.net")))
    assert(t.verify(address("bob+the_keyword.typenomatter.9ac20a3ca7a6fb@example.net")))
    assert(!t.verify(address("bob+the_keyword.k.9ac20a3ca7a6fe@example.net")))
    assert(!t.verify(address("bob+the_keyword.k.8ac20a3ca7a6fb@example.net")))
    assert(!t.verify(address("bob+a_keyword.k.9ac20a3ca7a6fb@example.net")))

    e = assert_exception(ArgumentError) {
      t.verify(address("bob@example.net"))
    }
    assert_equal("address not tagged", e.message)

    e = assert_exception(ArgumentError) {
      t.verify(address("bob+the_keyword.+.9ac20a3ca7a6fb@example.net"))
    }
    assert_equal("address not tagged", e.message)

    e = assert_exception(ArgumentError) {
      t.verify(address("bob+.k.9ac20a3ca7a6fb@example.net"))
    }
    assert_equal("address not tagged", e.message)

    e = assert_exception(ArgumentError) {
      t.verify(address("bob+the_keyword..9ac20a3ca7a6fb@example.net"))
    }
    assert_equal("address not tagged", e.message)

    e = assert_exception(ArgumentError) {
      t.verify(address("bob+the_keyword.k.+@example.net"))
    }
    assert_equal("address not tagged", e.message)
  end

end
