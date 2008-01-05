#!/usr/bin/env ruby
#--
#   Copyright (C) 2002, 2003 Matt Armstrong.  All rights reserved.
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

require 'test/testbase'
require 'rmail/serialize'
require 'rmail/message'

class TestRMailSerialize < TestBase
  def test_serialize_empty
    s = RMail::Serialize.new('').serialize(RMail::Message.new)
    assert_equal("", s)
  end

  def test_serialize_basic
    m = RMail::Message.new
    m.header['to'] = "bob@example.net"
    m.header['from'] = "sally@example.net"
    m.body = "This is the body."
    s = RMail::Serialize.new('').serialize(m)
    assert_equal(%q{to: bob@example.net
from: sally@example.net

This is the body.
},
                 s)
  end

  def test_serialize_s_write
    m = RMail::Message.new
    m.header['to'] = "bob@example.net"
    m.header['from'] = "sally@example.net"
    m.body = "This is the body."
    s = RMail::Serialize.write('', m)
    assert_equal(%q{to: bob@example.net
from: sally@example.net

This is the body.
},
                 s)
  end

  def test_serialize_boundary_generation
    m = RMail::Message.new
    m.add_part(RMail::Message.new)
    m.add_part(RMail::Message.new)

    m.part(0).body = "body0\n"
    m.part(1).body = "body1\n"

    m.to_s

    assert_match(/^=-\d+-\d+-\d+-\d+-\d+-=$/,
                 m.header.param('content-type', 'boundary'))
  end

  def test_serialize_boundary_override
    m = RMail::Message.new
    m.add_part(RMail::Message.new)
    m.header.set_boundary("a")

    m.part(0).add_part(RMail::Message.new)
    m.part(0).header.set_boundary("a")

    m.to_s

    assert_match(/^=-\d+-\d+-\d+-\d+-\d+-=$/,
                 m.part(0).header.param('content-type', 'boundary'))
    assert_equal("a", m.header.param('content-type', 'boundary'))
  end

  def test_serialize_multipart_basic
    m = RMail::Message.new
    m.header['to'] = "bob@example.net"
    m.header['from'] = "sally@example.net"
    m.header.set_boundary('=-=-=')
    part = RMail::Message.new
    part.body = "This is a text/plain part."
    m.add_part(part)
    part = RMail::Message.new
    part.body = "This is a whacked out wacky part.\n"
    part.header['Content-Disposition'] = 'inline'
    m.add_part(part)
    part = RMail::Message.new
    part.body = "This is another whacked out wacky part.\n\n"
    part.header['Content-Disposition'] = 'inline'
    m.add_part(part)
    s = RMail::Serialize.new('').serialize(m)
    assert_equal(%q{to: bob@example.net
from: sally@example.net
Content-Type: multipart/mixed; boundary="=-=-="
MIME-Version: 1.0


--=-=-=

This is a text/plain part.
--=-=-=
Content-Disposition: inline

This is a whacked out wacky part.

--=-=-=
Content-Disposition: inline

This is another whacked out wacky part.


--=-=-=--
},
                 s)
  end

  def test_serialize_multipart_nested
    m = RMail::Message.new
    m.header.set_boundary('=-=-=')

    part = RMail::Message.new
    m.add_part(part)
    m.part(0).header.set_boundary('==-=-=')

    part = RMail::Message.new
    m.part(0).add_part(RMail::Message.new)

    part = RMail::Message.new
    m.part(0).add_part(RMail::Message.new)

    s = RMail::Serialize.new('').serialize(m)
    assert_equal(%q{Content-Type: multipart/mixed; boundary="=-=-="
MIME-Version: 1.0


--=-=-=
Content-Type: multipart/mixed; boundary="==-=-="


--==-=-=

--==-=-=

--==-=-=--

--=-=-=--
},
                 s)
  end

  def test_serialize_multipart_epilogue_preamble
    m = RMail::Message.new
    m.preamble = %q{This is a multipart message in MIME format.
You are not using a message reader that understands MIME format.
Sucks to be you.}
    m.epilogue = %q{This is the end of a multipart message in MIME format.
You are not using a message reader that understands MIME format.
Sucks to be you.
}
    m.header['to'] = "bob@example.net"
    m.header['from'] = "sally@example.net"
    m.header.set_boundary('=-=-=')

    part = RMail::Message.new
    part.preamble = "SHOULD NOT SHOW UP"
    part.body = "This is the body of the first part."
    part.epilogue = "SHOULD NOT SHOW UP"
    m.add_part(part)

    part = RMail::Message.new
    part.body = "This is the body of the second part.\n"
    part.header['Content-Disposition'] = 'inline'
    m.add_part(part)

    part = RMail::Message.new
    part.body = "This is the body of the third part.\n\n"
    part.header['Content-Disposition'] = "inline\n"
    part.header['X-Silly-Header'] = "silly value\n"
    m.add_part(part)

    s = RMail::Serialize.new('').serialize(m)
    assert_equal(%q{to: bob@example.net
from: sally@example.net
Content-Type: multipart/mixed; boundary="=-=-="
MIME-Version: 1.0

This is a multipart message in MIME format.
You are not using a message reader that understands MIME format.
Sucks to be you.
--=-=-=

This is the body of the first part.
--=-=-=
Content-Disposition: inline

This is the body of the second part.

--=-=-=
Content-Disposition: inline
X-Silly-Header: silly value

This is the body of the third part.


--=-=-=--
This is the end of a multipart message in MIME format.
You are not using a message reader that understands MIME format.
Sucks to be you.
},
                 s)

    m.epilogue = "foo\n\n"
    s = RMail::Serialize.new('').serialize(m)
    assert_equal(%q{to: bob@example.net
from: sally@example.net
Content-Type: multipart/mixed; boundary="=-=-="
MIME-Version: 1.0

This is a multipart message in MIME format.
You are not using a message reader that understands MIME format.
Sucks to be you.
--=-=-=

This is the body of the first part.
--=-=-=
Content-Disposition: inline

This is the body of the second part.

--=-=-=
Content-Disposition: inline
X-Silly-Header: silly value

This is the body of the third part.


--=-=-=--
foo

},
                 s)
  end

end
