#!/usr/bin/env ruby
#--
#   Copyright (C) 2001, 2002 Matt Armstrong.  All rights reserved.
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

require 'rmail/message'
require 'test/testbase'

class TestRMailMessage < TestBase

  def setup
    super

    @the_mail_file = File.join(scratch_dir, "mail_file")

    @the_mail = %q{From: somedude@example.com
To: someotherdude@example.com
Subject: this is some mail

First body line.

Second body line.
}

    File.open(@the_mail_file, "w") { |file|
      file.print(@the_mail)
    }

    # Test reading in a mail file that has a bad header.  This makes
    # sure we consider the message header to be everything up to the
    # first blank line.
    @the_mail_file_2 = File.join(scratch_dir, "mail_file_2")
    @the_mail_2 = %q{From: somedude@example.com
To: someotherdude@example.com
this is not a valid header
Subject: this is some mail

First body line

Second body line
}
    File.open(@the_mail_file_2, "w") { |file|
      file.print(@the_mail_2)
    }
  end

  def verify_message_interface(message)
    assert_not_nil(message)
    assert_kind_of(RMail::Message, message)
    assert_not_nil(message.header)
    assert_kind_of(RMail::Header, message.header)
    assert_kind_of(Enumerable, message.header,
		    "RMail::Message.body should be an Enumerable")
  end

  def test_initialize

    # Make sure an empty message actually is empty
    message = RMail::Message.new
    verify_message_interface(message)
    assert_equal(message.header.length, 0)
    assert_nil(message.body)
  end

  def test_EQUAL
    m1 = RMail::Message.new
    m2 = RMail::Message.new
    assert(m1 == m2)

    m1.header['To'] = 'bob'
    assert(m1 != m2)
    m2.header['To'] = 'bob'
    assert(m1 == m2)

    m1.preamble = 'the preamble'
    assert(m1 != m2)
    m2.preamble = 'the preamble'
    assert(m1 == m2)

    m1.epilogue = 'the epilogue'
    assert(m1 != m2)
    m2.epilogue = 'the epilogue'
    assert(m1 == m2)

    m1.body = "the body"
    assert(m1 != m2)
    m2.body = "the body"
    assert(m1 == m2)

    m3 = RMail::Message.new
    m3.add_part(m1)
    m4 = RMail::Message.new
    m4.add_part(m2)
    assert(m3 == m4)

    m1.body = 'the other body'
    assert(m3 != m4)
  end

  def test_multipart?
    message = RMail::Message.new
    assert_equal(false, message.multipart?)
    message.add_part("This is a part.")
    assert_equal(true, message.multipart?)
    message.add_part("This is another part.")
    assert_equal(true, message.multipart?)
  end

  def test_add_part
    message = RMail::Message.new
    part_a = Object.new
    part_b = Object.new
    message.add_part(part_a)
    message.add_part(part_b)
    assert_same(part_a, message.part(0))
    assert_same(part_b, message.part(1))
  end

  def test_decode
    message = RMail::Message.new

    all_bytes = ''.force_encoding('ASCII-8BIT')
    0.upto(255) do |i|
      all_bytes << i
    end

    # These are base64 encoded strings that hold the data we'd really
    # like to test.  This avoids any problems with editors,
    # etc. stripping tabs or having screwed fontification, etc.
    base64_data = "CkFBRUNBd1FGQmdjSUNRb0xEQTBPRHhBUkVoTVVGUllYR0JrYUd4d2RIaDhn\nSVNJakpDVW1KeWdwS2lzc0xTNHZNREV5TXpRMQpOamM0T1RvN1BEMCtQMEJC\nUWtORVJVWkhTRWxLUzB4TlRrOVFVVkpUVkZWV1YxaFpXbHRjWFY1ZllHRmlZ\nMlJsWm1kb2FXcHIKYkcxdWIzQnhjbk4wZFhaM2VIbDZlM3g5Zm4rQWdZS0Ro\nSVdHaDRpSmlvdU1qWTZQa0pHU2s1U1ZscGVZbVpxYm5KMmVuNkNoCm9xT2tw\nYWFucUttcXE2eXRycSt3c2JLenRMVzJ0N2k1dXJ1OHZiNi93TUhDdzhURnhz\nZkl5Y3JMek0zT3o5RFIwdFBVMWRiWAoyTm5hMjl6ZDN0L2c0ZUxqNU9YbTUr\nanA2dXZzN2U3djhQSHk4L1QxOXZmNCtmcjcvUDMrL3c9PQo9MDA9MDE9MDI9\nMDM9MDQ9MDU9MDY9MDc9MDgJPTBBPTBCPTBDPTBEPTBFPTBGPTEwPTExPTEy\nPTEzPTE0PTE1PTE2PTE3PTE4PQo9MTk9MUE9MUI9MUM9MUQ9MUU9MUYgISIj\nJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0zRD4/QEFCQ0RFRkdISUpLTE1O\nT1BRUlM9Cgo=\n".unpack("m*").first
    qp_data = "PTAwPTAxPTAyPTAzPTA0PTA1PTA2PTA3PTA4CT0wQT0wQj0wQz0wRD0wRT0w\nRj0xMD0xMT0xMj0xMz0xND0xNT0xNj0xNz0xOD0KPTE5PTFBPTFCPTFDPTFE\nPTFFPTFGICEiIyQlJicoKSorLC0uLzAxMjM0NTY3ODk6Ozw9M0Q+P0BBQkNE\nRUZHSElKS0xNTk9QUVJTPQpUVVZXWFlaW1xdXl9gYWJjZGVmZ2hpamtsbW5v\ncHFyc3R1dnd4eXp7fH1+PTdGPTgwPTgxPTgyPTgzPTg0PTg1PTg2PTg3PTg4\nPQo9ODk9OEE9OEI9OEM9OEQ9OEU9OEY9OTA9OTE9OTI9OTM9OTQ9OTU9OTY9\nOTc9OTg9OTk9OUE9OUI9OUM9OUQ9OUU9OUY9QTA9QTE9Cj1BMj1BMz1BND1B\nNT1BNj1BNz1BOD1BOT1BQT1BQj1BQz1BRD1BRT1BRj1CMD1CMT1CMj1CMz1C\nND1CNT1CNj1CNz1COD1COT1CQT0KPUJCPUJDPUJEPUJFPUJGPUMwPUMxPUMy\nPUMzPUM0PUM1PUM2PUM3PUM4PUM5PUNBPUNCPUNDPUNEPUNFPUNGPUQwPUQx\nPUQyPUQzPQo9RDQ9RDU9RDY9RDc9RDg9RDk9REE9REI9REM9REQ9REU9REY9\nRTA9RTE9RTI9RTM9RTQ9RTU9RTY9RTc9RTg9RTk9RUE9RUI9RUM9Cj1FRD1F\nRT1FRj1GMD1GMT1GMj1GMz1GND1GNT1GNj1GNz1GOD1GOT1GQT1GQj1GQz1G\nRD1GRT1GRg==\n".unpack("m*").first

    base64_message = RMail::Message.new
    base64_message.header['Content-Transfer-Encoding'] = '  base64  '
    base64_message.body = base64_data
    message.add_part(base64_message)

    qp_message = RMail::Message.new
    qp_message.header['Content-Transfer-Encoding'] = '  quoted-printable  '
    qp_message.body = qp_data
    message.add_part(qp_message)

    e = assert_raise(TypeError) {
      message.decode
    }
    assert_equal('Can not decode a multipart message.', e.message)

    assert_equal(base64_message, message.part(0))
    assert_equal(qp_message, message.part(1))

    assert_equal(base64_data, message.part(0).body)
    assert_equal(qp_data, message.part(1).body)

    assert_equal(all_bytes, message.part(0).decode)
    assert_equal(all_bytes, message.part(1).decode)
  end

  def test_part
    message = RMail::Message.new

    e = assert_raise(TypeError) {
      message.part(0)
    }
    assert_equal('Can not get part on a single part message.', e.message)

    first = RMail::Message.new
    message.add_part(first)
    second = RMail::Message.new
    message.add_part(second)
    assert_equal(first, message.part(0))
    assert_equal(second, message.part(1))
  end

  def test_preamble
    m = RMail::Message.new
    assert_nil(m.preamble)
    m.preamble = "hello bob"
    assert_equal("hello bob", m.preamble)
    m.preamble = "hello bob\n"
    assert_equal("hello bob\n", m.preamble)
  end

  def test_epilogue
    m = RMail::Message.new
    assert_nil(m.epilogue)
    m.epilogue = "hello bob"
    assert_equal("hello bob", m.epilogue)
    m.epilogue = "hello bob\n"
    assert_equal("hello bob\n", m.epilogue)
  end

  def test_to_s
    begin
      m = RMail::Message.new
      m.header['To'] = 'bob@example.net'
      m.header['From'] = 'sam@example.com'
      m.header['Subject'] = 'hi bob'
      m.body = "Just wanted to say Hi!\n"

      desired =
        %q{To: bob@example.net
From: sam@example.com
Subject: hi bob

Just wanted to say Hi!
}
      assert_equal(desired, m.to_s)
    end

    begin
      m = RMail::Message.new
      m.header.set_boundary('=-=-=')
      part1 = RMail::Message.new
      part1.body = "part1 body"
      part2 = RMail::Message.new
      part2.body = "part2 body"
      m.add_part(part1)
      m.add_part(part2)
      assert_equal(%q{Content-Type: multipart/mixed; boundary="=-=-="
MIME-Version: 1.0


--=-=-=

part1 body
--=-=-=

part2 body
--=-=-=--
},
                   m.to_s)
    end
  end

end
