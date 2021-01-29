#!/usr/bin/env ruby
#--
#   Copyright (C) 2002 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

require 'tests/testbase'
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

    assert_match(/^=-\d+-\d+-\d+-\d+$/,
                 m.header.param('content-type', 'boundary'))
  end

  def test_serialize_boundary_override
    m = RMail::Message.new
    m.add_part(RMail::Message.new)
    m.header.set_boundary("a")

    m.part(0).add_part(RMail::Message.new)
    m.part(0).header.set_boundary("a")

    m.to_s

    assert_match(/^=-\d+-\d+-\d+-\d+$/,
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
