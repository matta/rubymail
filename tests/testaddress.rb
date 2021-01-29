#!/usr/bin/env ruby
#
#   Copyright (c) 2001 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

require 'tests/testbase'
require 'mail/address'

class TestMailAddress < TestBase

  def method_list
    [:display_name, :name, :address, :comments,
      :format, :domain, :local]
  end

  def validate_method(object, method, *args)
    assert(method_list.include?(method),
	   "#{method.inspect} not in #{method_list.inspect}")
    assert_respond_to(method, object)
    ret = nil
    ret = object.send(method, *args)
    if block_given?
      yield(ret)
    end
  end

  def validate_interface(address)
    assert_instance_of(Mail::Address, address)

    validate_method(address, :display_name) { |ret|
      assert_instance_of(String, ret) unless ret.nil?
    }

    validate_method(address, :name) { |ret|
      assert_instance_of(String, ret) unless ret.nil?
    }

    validate_method(address, :address) { |ret|
      assert_instance_of(String, ret) unless ret.nil?
    }

    validate_method(address, :comments) { |ret|
      unless ret.nil?
	assert_instance_of(Array, ret)
	ret.each { |comment|
	  assert_instance_of(String, comment)
	}
      end
    }

    validate_method(address, :format) { |ret|
      assert_instance_of(String, ret) unless ret.nil?
    }

    validate_method(address, :domain) { |ret|
      assert_instance_of(String, ret) unless ret.nil?
    }

    validate_method(address, :local) { |ret|
      assert_instance_of(String, ret) unless ret.nil?
    }
  end

  def validate_case(testcase, debug = false)
    begin
      prev_debug = $DEBUG
      $DEBUG = debug
      results = Mail::Address.parse(testcase[0])
    ensure
      $DEBUG = prev_debug
    end
    assert_kind_of(Array, results)
    results.each { |address|
      validate_interface(address)
    }
    expected_results = testcase[1]
    assert_instance_of(Array, expected_results)
    assert_equal(expected_results.length, results.length)

    results.each_with_index { |address, i|
      assert_instance_of(Hash, expected_results[i])
      methods = method_list
      expected_results[i].each { |method, expected|
	validate_method(address, method) { |ret|
	  assert_equal(expected, ret,
		       "string #{testcase[0].inspect} addr #{address.inspect} method #{method.inspect}")
	}
	methods.delete(method)
      }
      assert_equal(0, methods.length,
		   "test case did not test these methods #{methods.inspect}")
    }
  end

  def test_rfc_2822()

    # The following are from RFC2822
    validate_case\
    ['John Doe <jdoe@machine.example>',
      [ { :name => 'John Doe',
	  :display_name => 'John Doe',
	  :address => 'jdoe@machine.example',
	  :comments => nil,
	  :domain => 'machine.example',
	  :local => 'jdoe',
	  :format => 'John Doe <jdoe@machine.example>' } ]]

    validate_case\
    [' Mary Smith <mary@example.net>',
      [ { :name => 'Mary Smith',
	  :display_name => 'Mary Smith',
	  :address => 'mary@example.net',
	  :comments => nil,
	  :domain => 'example.net',
	  :local => 'mary',
	  :format => 'Mary Smith <mary@example.net>' } ]]

    validate_case\
    ['"Joe Q. Public" <john.q.public@example.com>',
      [ { :name => 'Joe Q. Public',
	  :display_name => 'Joe Q. Public',
	  :address => 'john.q.public@example.com',
	  :comments => nil,
	  :domain => 'example.com',
	  :local => 'john.q.public',
	  :format => '"Joe Q. Public" <john.q.public@example.com>' } ]]

    validate_case\
    ['Mary Smith <mary@x.test>, jdoe@example.org, Who? <one@y.test>',
      [ { :name => 'Mary Smith',
	  :display_name => 'Mary Smith',
	  :address => 'mary@x.test',
	  :comments => nil,
	  :domain => 'x.test',
	  :local => 'mary',
	  :format => 'Mary Smith <mary@x.test>' },
	{ :name => nil,
	  :display_name => nil,
	  :address => 'jdoe@example.org',
	  :comments => nil,
	  :domain => 'example.org',
	  :local => 'jdoe',
	  :format => 'jdoe@example.org' },
	{ :name => 'Who?',
	  :display_name => 'Who?',
	  :address => 'one@y.test',
	  :comments => nil,
	  :domain => 'y.test',
	  :local => 'one',
	  :format => 'Who? <one@y.test>' } ]]

    validate_case\
    ['<boss@nil.test>, "Giant; \"Big\" Box" <sysservices@example.net>',
      [ { :name => nil,
	  :display_name => nil,
	  :address => 'boss@nil.test',
	  :comments => nil,
	  :domain => 'nil.test',
	  :local => 'boss',
	  :format => 'boss@nil.test' },
	{ :name => 'Giant; "Big" Box',
	  :display_name => 'Giant; "Big" Box',
	  :address => 'sysservices@example.net',
	  :comments => nil,
	  :domain => 'example.net',
	  :local => 'sysservices',
	  :format => '"Giant; \"Big\" Box" <sysservices@example.net>' }
      ] ]

    validate_case\
    ['A Group:Chris Jones <c@a.test>,joe@where.test,John <jdoe@one.test>;',
      [ { :name => 'Chris Jones',
	  :display_name => 'Chris Jones',
	  :address => 'c@a.test',
	  :comments => nil,
	  :domain => 'a.test',
	  :local => 'c',
	  :format => 'Chris Jones <c@a.test>' },
	{ :name => nil,
	  :display_name => nil,
	  :address => 'joe@where.test',
	  :comments => nil,
	  :domain => 'where.test',
	  :local => 'joe',
	  :format => 'joe@where.test' },
	{ :name => 'John',
	  :display_name => 'John',
	  :address => 'jdoe@one.test',
	  :comments => nil,
	  :domain => 'one.test',
	  :local => 'jdoe',
	  :format => 'John <jdoe@one.test>' }
      ] ]

    validate_case\
    ['Undisclosed recipients:;',
      [] ]

    validate_case\
    ['undisclosed recipients: ;',
      [] ]

    validate_case\
    ['"Mary Smith: Personal Account" <smith@home.example>   ',
      [ { :name => 'Mary Smith: Personal Account',
	  :display_name => 'Mary Smith: Personal Account',
	  :address => 'smith@home.example',
	  :comments => nil,
	  :domain => 'home.example',
	  :local => 'smith',
	  :format => '"Mary Smith: Personal Account" <smith@home.example>' }
      ] ]

    validate_case\
    ['Pete(A wonderful \) chap) <pete(his account)@silly.test(his host)>',
      [ { :name => 'Pete',
	  :display_name => 'Pete',
	  :address => 'pete@silly.test',
	  :comments => ['A wonderful ) chap', 'his account', 'his host'],
	  :domain => 'silly.test',
	  :local => 'pete',
	  :format => 'Pete <pete@silly.test> (A wonderful \) chap) (his account) (his host)' }
      ] ]

    validate_case\
    ["A Group(Some people)\r\n     :Chris Jones <c@(Chris's host.)public.example>,\r\n         joe@example.org",
      [ { :name => 'Chris Jones',
	  :display_name => 'Chris Jones',
	  :address => 'c@public.example',
	  :comments => ['Chris\'s host.'],
	  :domain => 'public.example',
	  :local => 'c',
	  :format => 'Chris Jones <c@public.example> (Chris\'s host.)' },
	{ :name => nil,
	  :display_name => nil,
	  :address => 'joe@example.org',
	  :comments => nil,
	  :domain => 'example.org',
	  :local => 'joe',
	  :format => 'joe@example.org' }
	] ]

    validate_case\
    ['(Empty list)(start)Undisclosed recipients  :(nobody(that I know))  ;',
      [] ]

    # Note, the space is lost after the Q. because we always convert
    # word . word into "word.word" for output.  To preserve the space,
    # the guy should quote his name.
    validate_case\
    ['Joe Q. Public <john.q.public@example.com>',
      [ { :name => 'Joe Q.Public',
	  :display_name => 'Joe Q.Public',
	  :address => 'john.q.public@example.com',
	  :comments => nil,
	  :domain => 'example.com',
	  :local => 'john.q.public',
	  :format => '"Joe Q.Public" <john.q.public@example.com>' } ] ]
	
    validate_case\
    ['Mary Smith <@machine.tld:mary@example.net>, , jdoe@test   . example',
      [ { :name => 'Mary Smith',
	  :display_name => 'Mary Smith',
	  :address => 'mary@example.net',
	  :comments => nil,
	  :domain => 'example.net',
	  :local => 'mary',
	  :format => 'Mary Smith <mary@example.net>' },
	{ :name => nil,
	  :display_name => nil,
	  :address => 'jdoe@test.example',
	  :comments => nil,
	  :domain => 'test.example',
	  :local => 'jdoe',
	  :format => 'jdoe@test.example' } ] ]

    validate_case\
    ['John Doe <jdoe@machine(comment).  example>',
      [ { :name => 'John Doe',
	  :display_name => 'John Doe',
	  :address => 'jdoe@machine.example',
	  :comments => ['comment'],
	  :domain => 'machine.example',
	  :local => 'jdoe',
	  :format => 'John Doe <jdoe@machine.example> (comment)' } ] ]

    validate_case\
    ["Mary Smith\n\r                  \n          <mary@example.net>",
      [ { :name => 'Mary Smith',
	  :display_name => 'Mary Smith',
	  :address => 'mary@example.net',
	  :comments => nil,
	  :domain => 'example.net',
	  :local => 'mary',
	  :format => 'Mary Smith <mary@example.net>' } ] ]
  end

  def test_mailtools_suite()

    #
    # The following are from the Perl MailTools module version 1.40
    #
    validate_case\
    ['"Joe & J. Harvey" <ddd @Org>, JJV @ BBN',
      [	{ :name => 'Joe & J. Harvey',
	  :display_name => 'Joe & J. Harvey',
	  :address => 'ddd@Org',
	  :comments => nil,
	  :domain => 'Org',
	  :local => 'ddd',
	  :format => '"Joe & J. Harvey" <ddd@Org>' },
	{ :name => nil,
	  :display_name => nil,
	  :address => 'JJV@BBN',
	  :comments => nil,
	  :domain => 'BBN',
	  :local => 'JJV',
	  :format => 'JJV@BBN' } ] ]

    validate_case\
    ['"spickett@tiac.net" <Sean.Pickett@zork.tiac.net>',
      [ { :name => 'spickett@tiac.net',
	  :display_name => 'spickett@tiac.net',
	  :address => 'Sean.Pickett@zork.tiac.net',
	  :comments => nil,
	  :domain => 'zork.tiac.net',
	  :local => 'Sean.Pickett',
	  :format => '"spickett@tiac.net" <Sean.Pickett@zork.tiac.net>' } ] ]

    validate_case\
    ['rls@intgp8.ih.att.com (-Schieve,R.L.)',
      [ { :name => '-Schieve,R.L.',
	  :display_name => nil,
	  :address => 'rls@intgp8.ih.att.com',
	  :comments => ['-Schieve,R.L.'],
	  :domain => 'intgp8.ih.att.com',
	  :local => 'rls',
	  :format => 'rls@intgp8.ih.att.com (-Schieve,R.L.)' } ] ]

    validate_case\
    ['jrh%cup.portal.com@portal.unix.portal.com',
      [ { :name => nil,
	  :display_name => nil,
	  :address => 'jrh%cup.portal.com@portal.unix.portal.com',
	  :comments => nil,
	  :domain => 'portal.unix.portal.com',
	  :local => 'jrh%cup.portal.com',
	  :format => 'jrh%cup.portal.com@portal.unix.portal.com' } ] ]

    validate_case\
    ['astrachan@austlcm.sps.mot.com (\'paul astrachan/xvt3\')',
      [ { :name => '\'paul astrachan/xvt3\'',
	  :display_name => nil,
	  :address => 'astrachan@austlcm.sps.mot.com',
	  :comments => ['\'paul astrachan/xvt3\''],
	  :domain => 'austlcm.sps.mot.com',
	  :local => 'astrachan',
	  :format =>
	  'astrachan@austlcm.sps.mot.com (\'paul astrachan/xvt3\')' } ] ]

    validate_case\
    ['TWINE57%SDELVB.decnet@SNYBUF.CS.SNYBUF.EDU (JAMES R. TWINE - THE NERD)',
      [ { :name => 'JAMES R. TWINE - THE NERD',
	  :display_name => nil,
	  :address => 'TWINE57%SDELVB.decnet@SNYBUF.CS.SNYBUF.EDU',
	  :comments => ['JAMES R. TWINE - THE NERD'],
	  :domain => 'SNYBUF.CS.SNYBUF.EDU',
	  :local => 'TWINE57%SDELVB.decnet',
	  :format =>
	  'TWINE57%SDELVB.decnet@SNYBUF.CS.SNYBUF.EDU (JAMES R. TWINE - THE NERD)'} ] ]

    validate_case\
    ['David Apfelbaum <da0g+@andrew.cmu.edu>',
      [ { :name => 'David Apfelbaum',
	  :display_name => 'David Apfelbaum',
	  :address => 'da0g+@andrew.cmu.edu',
	  :comments => nil,
	  :domain => 'andrew.cmu.edu',
	  :local => 'da0g+',
	  :format => 'David Apfelbaum <da0g+@andrew.cmu.edu>' } ] ]

    validate_case\
    ['"JAMES R. TWINE - THE NERD" <TWINE57%SDELVB%SNYDELVA.bitnet@CUNYVM.CUNY.EDU>',
      [ { :name => 'JAMES R. TWINE - THE NERD',
	  :display_name => 'JAMES R. TWINE - THE NERD',
	  :address => 'TWINE57%SDELVB%SNYDELVA.bitnet@CUNYVM.CUNY.EDU',
	  :comments => nil,
	  :domain => 'CUNYVM.CUNY.EDU',
	  :local => 'TWINE57%SDELVB%SNYDELVA.bitnet',
	  :format => '"JAMES R. TWINE - THE NERD" <TWINE57%SDELVB%SNYDELVA.bitnet@CUNYVM.CUNY.EDU>' } ] ]

    validate_case\
    ['/G=Owen/S=Smith/O=SJ-Research/ADMD=INTERSPAN/C=GB/@mhs-relay.ac.uk',
      [ { :name => nil,
	  :display_name => nil,
	  :address => '/G=Owen/S=Smith/O=SJ-Research/ADMD=INTERSPAN/C=GB/@mhs-relay.ac.uk',
	  :comments => nil,
	  :domain => 'mhs-relay.ac.uk',
	  :local => '/G=Owen/S=Smith/O=SJ-Research/ADMD=INTERSPAN/C=GB/',
	  :format => '/G=Owen/S=Smith/O=SJ-Research/ADMD=INTERSPAN/C=GB/@mhs-relay.ac.uk' } ] ]

    validate_case\
    ['"Stephen Burke, Liverpool" <BURKE@vxdsya.desy.de>',
      [ { :name => 'Stephen Burke, Liverpool',
	  :display_name => 'Stephen Burke, Liverpool',
	  :address => 'BURKE@vxdsya.desy.de',
	  :comments => nil,
	  :domain => 'vxdsya.desy.de',
	  :local => 'BURKE',
	  :format => '"Stephen Burke, Liverpool" <BURKE@vxdsya.desy.de>' } ] ]

    validate_case\
    ['The Newcastle Info-Server <info-admin@newcastle.ac.uk>',
      [ { :name => 'The Newcastle Info-Server',
	  :display_name => 'The Newcastle Info-Server',
	  :address => 'info-admin@newcastle.ac.uk',
	  :comments => nil,
	  :domain => 'newcastle.ac.uk',
	  :local => 'info-admin',
	  :format => 'The Newcastle Info-Server <info-admin@newcastle.ac.uk>'
	} ] ]

    validate_case\
    ['Suba.Peddada@eng.sun.com (Suba Peddada [CONTRACTOR])',
      [ { :name => 'Suba Peddada [CONTRACTOR]',
	  :display_name => nil,
	  :address => 'Suba.Peddada@eng.sun.com',
	  :comments => ['Suba Peddada [CONTRACTOR]'],
	  :domain => 'eng.sun.com',
	  :local => 'Suba.Peddada',
	  :format => 'Suba.Peddada@eng.sun.com (Suba Peddada [CONTRACTOR])'
	} ] ]

    validate_case\
    ['Paul Manser (0032 memo) <a906187@tiuk.ti.com>',
      [ { :name => 'Paul Manser',
	  :display_name => 'Paul Manser',
	  :address => 'a906187@tiuk.ti.com',
	  :comments => ['0032 memo'],
	  :domain => 'tiuk.ti.com',
	  :local => 'a906187',
	  :format => 'Paul Manser <a906187@tiuk.ti.com> (0032 memo)' } ] ]

    validate_case\
    ['"gregg (g.) woodcock" <woodcock@bnr.ca>',
      [ { :name => 'gregg (g.) woodcock',
	  :display_name => 'gregg (g.) woodcock',
	  :address => 'woodcock@bnr.ca',
	  :comments => nil,
	  :domain => 'bnr.ca',
	  :local => 'woodcock',
	  :format => '"gregg (g.) woodcock" <woodcock@bnr.ca>' } ] ]

    validate_case\
    ['Graham.Barr@tiuk.ti.com',
      [ { :name => nil,
	  :display_name => nil,
	  :address => 'Graham.Barr@tiuk.ti.com',
	  :comments => nil,
	  :domain => 'tiuk.ti.com',
	  :local => 'Graham.Barr',
	  :format => 'Graham.Barr@tiuk.ti.com' } ] ]

    validate_case\
    ['a909937 (Graham Barr          (0004 bodg))',
      [ { :name => 'Graham Barr (0004 bodg)',
	  :display_name => nil,
	  :address => 'a909937',
	  :comments => ['Graham Barr (0004 bodg)'],
	  :domain => nil,
	  :local => 'a909937',
	  :format => 'a909937 (Graham Barr \(0004 bodg\))' } ] ]

    validate_case\
    ['david d `zoo\' zuhn <zoo@aggregate.com>',
      [ { :name => 'david d `zoo\' zuhn',
	  :display_name => 'david d `zoo\' zuhn',
	  :address => 'zoo@aggregate.com',
	  :comments => nil,
	  :domain => 'aggregate.com',
	  :local => 'zoo',
	  :format => 'david d `zoo\' zuhn <zoo@aggregate.com>' } ] ]

    validate_case\
    ['(foo@bar.com (foobar), ned@foo.com (nedfoo) ) <kevin@goess.org>',
      [ { :name => 'foo@bar.com (foobar), ned@foo.com (nedfoo) ',
	  :display_name => nil,
	  :address => 'kevin@goess.org',
	  :comments => ['foo@bar.com (foobar), ned@foo.com (nedfoo) '],
	  :domain => 'goess.org',
	  :local => 'kevin',
	  :format =>
	  'kevin@goess.org (foo@bar.com \(foobar\), ned@foo.com \(nedfoo\) )'
	} ]]
  end

  def test_rfc_822

    validate_case\
    ['":sysmail"@ Some-Group. Some-Org, Muhammed.(I am the greatest) Ali @(the)Vegas.WBA',
      [ { :name => nil,
	  :display_name => nil,
	  :address => ':sysmail@Some-Group.Some-Org',
	  :comments => nil,
	  :domain => 'Some-Group.Some-Org',
	  :local => ':sysmail',
	  :format => '":sysmail"@Some-Group.Some-Org' },
	{ :name => 'the',
	  :display_name => nil,
	  :address => 'Muhammed.Ali@Vegas.WBA',
	  :comments => ['I am the greatest', 'the'],
	  :domain => 'Vegas.WBA',
	  :local => 'Muhammed.Ali',
	  :format => 'Muhammed.Ali@Vegas.WBA (I am the greatest) (the)' } ] ]
  end

  def test_misc_addresses()
    # From Python address parsing bug list.  This is valid according
    # to RFC2822.
    validate_case(['Amazon.com <delivers-news2@amazon.com>',
		    [ { :name => 'Amazon.com',
			:display_name => 'Amazon.com',
			:address => 'delivers-news2@amazon.com',
			:comments => nil,
			:domain => 'amazon.com',
			:local => 'delivers-news2',
			:format => '"Amazon.com" <delivers-news2@amazon.com>'
		      } ] ])
      
    validate_case\
    ["\r\n  Amazon \r . \n com \t <    delivers-news2@amazon.com  >  \n  ",
      [ { :name => 'Amazon.com',
	  :display_name => 'Amazon.com',
	  :address => 'delivers-news2@amazon.com',
	  :comments => nil,
	  :domain => 'amazon.com',
	  :local => 'delivers-news2',
	  :format => '"Amazon.com" <delivers-news2@amazon.com>'
	} ] ]
      
    # From postfix-users@postfix.org
    # Date: Tue, 13 Nov 2001 10:58:23 -0800
    # Subject: Apparent bug in strict_rfc821_envelopes (Snapshot-20010714)
    validate_case\
    ['"mailto:rfc"@monkeys.test',
      [ { :name => nil,
	  :display_name => nil,
	  :address => 'mailto:rfc@monkeys.test',
	  :comments => nil,
	  :domain => 'monkeys.test',
	  :local => 'mailto:rfc',
	  :format => '"mailto:rfc"@monkeys.test' } ] ]

    # An unquoted mailto:rfc will end up having the mailto: portion
    # discarded as a group name.
    validate_case\
    ['mailto:rfc@monkeys.test',
      [ { :name => nil,
	  :display_name => nil,
	  :address => 'rfc@monkeys.test',
	  :comments => nil,
	  :domain => 'monkeys.test',
	  :local => 'rfc',
	  :format => 'rfc@monkeys.test' } ] ]

    # From gnu.emacs.help
    # Date: 24 Nov 2001 15:37:23 -0500
    validate_case\
    ['"Stefan Monnier <foo@acm.com>" <monnier+gnu.emacs.help/news/@flint.cs.yale.edu>',
      [ { :name => 'Stefan Monnier <foo@acm.com>',
	  :display_name => 'Stefan Monnier <foo@acm.com>',
	  :address => 'monnier+gnu.emacs.help/news/@flint.cs.yale.edu',
	  :comments => nil,
	  :domain => 'flint.cs.yale.edu',
	  :local => 'monnier+gnu.emacs.help/news/',
	  :format => '"Stefan Monnier <foo@acm.com>" <monnier+gnu.emacs.help/news/@flint.cs.yale.edu>' } ] ]

	{ :name => nil,
	  :display_name => nil,
	  :address => nil,
	  :comments => nil,
	  :domain => nil,
	  :local => nil,
	  :format => nil }

    validate_case\
    ['"foo:" . bar@somewhere.test',
      [ { :name => nil,
	  :display_name => nil,
	  :address => 'foo:.bar@somewhere.test',
	  :comments => nil,
	  :domain => 'somewhere.test',
	  :local => 'foo:.bar',
	  :format => '"foo:.bar"@somewhere.test' } ] ]

    validate_case\
    ['Some Dude <"foo:" . bar@somewhere.test>',
      [ { :name => 'Some Dude',
	  :display_name => 'Some Dude',
	  :address => 'foo:.bar@somewhere.test',
	  :comments => nil,
	  :domain => 'somewhere.test',
	  :local => 'foo:.bar',
	  :format => 'Some Dude <"foo:.bar"@somewhere.test>' } ] ]

    validate_case\
    ['"q\uo\ted"@example.com, Luke Skywalker <"use"."the.force"@space.test>',
      [ { :name => nil,
	  :display_name => nil,
	  :address => 'quoted@example.com',
	  :comments => nil,
	  :domain => 'example.com',
	  :local => 'quoted',
	  :format => 'quoted@example.com' },
	{ :name => 'Luke Skywalker',
	  :display_name => 'Luke Skywalker',
	  :address => 'use.the.force@space.test',
	  :comments => nil,
	  :domain => 'space.test',
	  :local => 'use.the.force',
	  :format => 'Luke Skywalker <use.the.force@space.test>' } ] ]

    validate_case\
    ['Erik =?ISO-8859-1?Q?B=E5gfors?= <erik@example.net>',
      [ { :name => 'Erik =?ISO-8859-1?Q?B=E5gfors?=',
	  :display_name => 'Erik =?ISO-8859-1?Q?B=E5gfors?=',
	  :address => 'erik@example.net',
	  :comments => nil,
	  :domain => 'example.net',
	  :local => 'erik',
	  :format => 'Erik =?ISO-8859-1?Q?B=E5gfors?= <erik@example.net>'
	} ] ]
  end

  def test_domain_literal

    validate_case\
    ['test@[domain]',
      [ { :name => nil,
	  :display_name => nil,
	  :address => 'test@[domain]',
	  :comments => nil,
	  :domain => '[domain]',
	  :local => 'test',
	  :format => '<test@[domain]>' } ] ]

    validate_case\
    ['<@[obsdomain]:test@[domain]>',
      [ { :name => nil,
	  :display_name => nil,
	  :address => 'test@[domain]',
	  :comments => nil,
	  :domain => '[domain]',
	  :local => 'test',
	  :format => '<test@[domain]>' } ] ]

    validate_case\
    ['<@[ob\]sd\\\\omain]:test@[dom\]ai\\\\n]>',
      [ { :name => nil,
	  :display_name => nil,
	  :address => 'test@[dom]ai\\n]',
	  :comments => nil,
	  :domain => '[dom]ai\\n]',
	  :local => 'test',
	  :format => '<test@[dom\]ai\\\\n]>' } ] ]

    validate_case\
    ["Bob \r<@machine.tld  \r,\n [obsdomain]\t:\ntest @ [domain]>",
      [ { :name => 'Bob',
	  :display_name => 'Bob',
	  :address => 'test@[domain]',
	  :comments => nil,
	  :domain => '[domain]',
	  :local => 'test',
	  :format => 'Bob <test@[domain]>' } ] ]
  end

  def test_exhaustive()

    # We don't test every alphanumeric in atext -- assume that if a, m
    # and z work, they all will.
    atext = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a +
      '!#$%&\'*+-/=?^_`{|}~'.split(//) #/
    boring = ('b'..'l').to_a + ('n'..'o').to_a +
      ('p'..'y').to_a + ('B'..'L').to_a + ('N'..'O').to_a +
      ('P'..'Y').to_a + ('1'..'4').to_a + ('6'..'8').to_a

    (atext - boring).each {|ch|
      validate_case(["#{ch} <#{ch}@test>",
		      [ { :name => ch,
			  :display_name => ch,
			  :address => "#{ch}@test",
			  :comments => nil,
			  :domain => 'test',
			  :local => ch,
			  :format => ch + ' <' + ch + '@test>' } ] ])
    }
    
    validate_case([atext.join('') + ' <' + atext.join('') + '@test>',
		    [ { :name => atext.join(''),
			:display_name => atext.join(''),
			:address => atext.join('') + '@test',
			:comments => nil,
			:domain => 'test',
			:local => atext.join(''),
			:format => atext.join('') + ' <' + atext.join('') +
			'@test>' } ] ])

    ascii = (0..127).collect {|i| i.chr}
    whitespace = ["\r", "\n", ' ', "\t"]
    qtext = ascii - (whitespace + ['"', '\\'])
    ctext = ascii - (whitespace + ['(', ')', '\\'])
    dtext = ascii - (whitespace + ['[', ']', '\\'])

    (qtext - atext).each {|ch|
      validate_case(["\"#{ch}\" <\"#{ch}\"@test>",
		      [ { :name => ch,
			  :display_name => ch,
			  :address => "#{ch}@test",
			  :comments => nil,
			  :domain => 'test',
			  :local => "#{ch}",
			  :format => "\"#{ch}\" <\"#{ch}\"@test>" } ] ])
    }
    ['"', "\\"].each {|ch|
      validate_case(["\"\\#{ch}\" <\"\\#{ch}\"@test>",
		      [ { :name => ch,
			  :display_name => ch,
			  :address => ch + '@test',
			  :comments => nil,
			  :domain => 'test',
			  :local => ch,
			  :format => "\"\\#{ch}\" <\"\\#{ch}\"@test>" } ] ])
    }

    (ctext - boring).each {|ch|
      validate_case(["bob@test (#{ch})",
		      [ { :name => ch,
			  :display_name => nil,
			  :address => 'bob@test',
			  :comments => ["#{ch}"],
			  :domain => 'test',
			  :local => 'bob',
			  :format => "bob@test (#{ch})" } ] ])
      validate_case(["bob@test (\\#{ch})",
		      [ { :name => ch,
			  :display_name => nil,
			  :address => 'bob@test',
			  :comments => ["#{ch}"],
			  :domain => 'test',
			  :local => 'bob',
			  :format => "bob@test (#{ch})" } ] ])
    }
    [')', '(', '\\'].each {|ch|
      validate_case(["bob@test (\\#{ch})",
		      [ { :name => ch,
			  :display_name => nil,
			  :address => 'bob@test',
			  :comments => ["#{ch}"],
			  :domain => 'test',
			  :local => 'bob',
			  :format => 'bob@test (\\' + ch + ')' } ] ])
    }

    (dtext - boring).each {|ch|
      validate_case(["test@[\\#{ch}] (Sam)",
		      [ { :name => "Sam",
			  :display_name => nil,
			  :address => 'test@[' + ch + ']',
			  :comments => ["Sam"],
			  :domain => '[' + ch + ']',
			  :local => 'test',
			  :format => "<test@[#{ch}]> (Sam)" } ] ] )
      validate_case(["Sally <test@[\\#{ch}]>",
		      [ { :name => "Sally",
			  :display_name => "Sally",
			  :address => 'test@[' + ch + ']',
			  :comments => nil,
			  :domain => '[' + ch + ']',
			  :local => 'test',
			  :format => "Sally <test@[#{ch}]>" } ] ] )
    }

    validate_case(["test@[" + (dtext - boring).join('') + "]",
		    [ { :name => nil,
			:display_name => nil,
			:address => 'test@[' + (dtext - boring).join('') + "]",
			:comments => nil,
			:domain => '[' + (dtext - boring).join('') + ']',
			:local => 'test',
			:format => "<test@[" +
			(dtext - boring).join('') + "]>" } ] ])
    validate_case(["Bob <test@[" + (dtext - boring).join('') + "]>",
		    [ { :name => "Bob",
			:display_name => "Bob",
			:address => 'test@[' + (dtext - boring).join('') + "]",
			:comments => nil,
			:domain => '[' + (dtext - boring).join('') + ']',
			:local => 'test',
			:format => "Bob <test@[" +
			(dtext - boring).join('') + "]>" } ] ])
  end

  def test_out_of_spec()

    validate_case\
    ['bodg fred@tiuk.ti.com',
      [ { :name => nil,
	  :display_name => nil,
	  :address => 'bodg fred@tiuk.ti.com',
	  :comments => nil,
	  :domain => 'tiuk.ti.com',
	  :local => 'bodg fred',
	  :format => '"bodg fred"@tiuk.ti.com' } ] ]

    validate_case\
    ['<Investor Alert@example.com>',
      [ { :name => nil,
	  :display_name => nil,
	  :address => 'Investor Alert@example.com',
	  :comments => nil,
	  :domain => 'example.com',
	  :local => 'Investor Alert',
	  :format => '"Investor Alert"@example.com' } ] ]
    
    validate_case\
    ['"" <bob@example.com>',
      [ { :name => nil,
	  :display_name => nil,
	  :address => 'bob@example.com',
	  :comments => nil,
	  :domain => 'example.com',
	  :local => 'bob',
	  :format => 'bob@example.com' } ] ]

    validate_case\
    ['"" <""@example.com>',
      [ ] ]

    validate_case\
    ['@example.com',
      [ ] ]

    validate_case\
    ['bob',
      [ { :name => nil,
	  :display_name => nil,
	  :address => 'bob',
	  :comments => nil,
	  :domain => nil,
	  :local => 'bob',
	  :format => 'bob' } ] ]

    validate_case\
    ['bob,sally, sam',
      [ { :name => nil,
	  :display_name => nil,
	  :address => 'bob',
	  :comments => nil,
	  :domain => nil,
	  :local => 'bob',
	  :format => 'bob' },
	{ :name => nil,
	  :display_name => nil,
	  :address => 'sally',
	  :comments => nil,
	  :domain => nil,
	  :local => 'sally',
	  :format => 'sally' },
	{ :name => nil,
	  :display_name => nil,
	  :address => 'sam',
	  :comments => nil,
	  :domain => nil,
	  :local => 'sam',
	  :format => 'sam' }] ]

    validate_case(['Undisclosed <>', []])
    validate_case(['"Mensagem Automatica do Terra" <>', []])
  end

  def call_fails(arg, &block)
    begin
      yield arg
    rescue
      return true
    end
    return false
  end
  
  # if a random string failes, run it through this function to find the
  # shortest fail case
  def find_shortest_failure(arg, &block)
    unless call_fails(arg, &block)
      nil
    else
      # Chop off stuff from the beginning and then the end
      # until it stops failing
      bad = arg
      0.upto(bad.length) {|index|
	bad.length.downto(1) {|length|
	  begin
	    loop {
	      s = bad.dup
	      s[index,length] = ''
	      break if bad == s
	      break unless call_fails(s, &block)
	      bad = s
	    }
	  rescue IndexError
	    break
	  end
	}
      }
      bad
    end
  end

  def test_random_strings
    
    # These random strings have generated exceptions before, so test
    # them forever.
    Mail::Address.parse("j732[S\031\022\000\fuh\003Ye<2psd\005#1L=Hw*c\0247\006\aE\fXJ\026;\026\032zAAgpCFq+\010")
    Mail::Address.parse("\016o7=\024d^\001|h<,#\026~(<oS\005 f<u\022u+4\"\020d \023h\004)\036\016\023YY0\n]W]'\025S\t\035")
    Mail::Address.parse("<")
    
    0.upto(25) {
      specials = ',;\\()":@<>'
      strings = [(0..rand(255)).collect {rand(127).chr}.to_s,
	(0..255).collect {rand(255).chr}.to_s,
	(0..255).collect {
	  r = rand(specials.length * 5)
	  case r
	  when 0 .. specials.length - 1
	    specials[r].chr
	  else
	    rand(127).chr
	  end
	}.to_s ]
      strings.each {|string|
	assert_no_exception("failed for string #{string.inspect}") {
	  addrs = Mail::Address.parse(string)
	  addrs.each {|address|
	    method_list.each {|method|
	      address.send(method)
	    }
	  }
	}
      }
    }
  end
end

if __FILE__ == $0
  require 'runit/cui/testrunner'
  RUNIT::CUI::TestRunner.run(TestMailAddress.suite)
end
