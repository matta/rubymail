#
#   Copyright (C) 2002, 2003 Matt Armstrong.  All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The name of the author may not be used to endorse or promote
#    products derived from this software without specific prior
#    written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
# GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
# IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
# IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

require 'test/testbase'

begin
  require 'mail/tagged'

  class TC_AddressTagger < TestBase

    def address(s)
      RMail::Filter::Address.parse(s)[0]
    end

    def test_tag_dated
      a1 = address("Bob Smith <bob@example.net>")
      t = RMail::Filter::AddressTagger.new("the key", "+", 10)
      a2 = t.dated(a1, Time.now + 60)
      assert_equal("bob", a1.local)
      assert_match(/^bob\+\d{12}\.d\.[\da-h]{20}$/, a2.local)

      # Test varying the strength
      a1 = address("Bob Smith <bob@example.net>")
      t = RMail::Filter::AddressTagger.new("the key", "+", 3)
      a2 = t.dated(a1, Time.now + 60)
      assert_equal("bob", a1.local)
      assert_match(/^bob\+\d{12}\.d\.[\da-h]{6}$/, a2.local)
    end

    def test_tag_keyword
      a1 = address("Bob Smith <bob@example.net>")
      t = RMail::Filter::AddressTagger.new("the key", "+", 10)
      a2 = t.keyword(a1, "the keyword")
      assert_equal("bob", a1.local)
      assert_match(/^bob\+the_keyword\.k\.[\da-h]{20}$/, a2.local)

      # Test varying the strength
      a1 = address("Bob Smith <bob@example.net>")
      t = RMail::Filter::AddressTagger.new("the key", "+", 3)
      a2 = t.keyword(a1, "the keyword")
      assert_equal("bob", a1.local)
      assert_match(/^bob\+the_keyword\.k\.[\da-h]{6}$/, a2.local)
    end

    def test_verify
      t = RMail::Filter::AddressTagger.new("the key", "+", 7)

      assert(t.verify(address("bob+the_keyword.k.9ac20a3ca7a6fb@example.net")))
      assert(t.verify(address("bob+the_keyword.typenomatter.9ac20a3ca7a6fb@example.net")))
      assert(!t.verify(address("bob+the_keyword.k.9ac20a3ca7a6fe@example.net")))
      assert(!t.verify(address("bob+the_keyword.k.8ac20a3ca7a6fb@example.net")))
      assert(!t.verify(address("bob+a_keyword.k.9ac20a3ca7a6fb@example.net")))

      e = assert_raise(ArgumentError) {
        t.verify(address("bob@example.net"))
      }
      assert_equal("address not tagged", e.message)

      e = assert_raise(ArgumentError) {
        t.verify(address("bob+the_keyword.+.9ac20a3ca7a6fb@example.net"))
      }
      assert_equal("address not tagged", e.message)

      e = assert_raise(ArgumentError) {
        t.verify(address("bob+.k.9ac20a3ca7a6fb@example.net"))
      }
      assert_equal("address not tagged", e.message)

      e = assert_raise(ArgumentError) {
        t.verify(address('"bob+the_keyword..9ac20a3ca7a6fb"@example.net'))
      }
      assert_equal("address not tagged", e.message)

      e = assert_raise(ArgumentError) {
        t.verify(address("bob+the_keyword.k.+@example.net"))
      }
      assert_equal("address not tagged", e.message)
    end
  end
rescue LoadError
end
