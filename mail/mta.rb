=begin
   Copyright (C) 2001 Matt Armstrong.  All rights reserved.

   Permission is granted for use, copying, modification, distribution,
   and distribution of modified versions of this work as long as the
   above copyright notice is included.
=end

module Mail

  # <tt>Mail::MTA</tt> currently holds the EX_ constants from
  # sysexits.h as well as a few EXITCODE_ constants that can be used
  # when returning an error to an SMTP delivery agent (e.g. through a
  # <tt>.forward</tt> script).

  module MTA
    
    EX_USAGE = 64		# command line usage error
    EX_DATAERR = 65		# data format error
    EX_NOINPUT = 66		# cannot open input
    EX_NOUSER = 67		# addressee unknown
    EX_NOHOST = 68		# hostname unknown
    EX_UNAVAILABLE = 69		# service unavailable
    EX_SOFTWARE = 70		# internal software error
    EX_OSERR = 71		# system error (e.g., can't fork)
    EX_OSFILE = 72		# critical OS file missing
    EX_CANTCREAT = 73		# can't create (user) output file
    EX_IOERR = 74		# input/output error
    EX_TEMPFAIL = 75		# temp failure; user is invited to retry
    EX_PROTOCOL = 76		# remote error in protocol
    EX_NOPERM = 77		# permission denied
    EX_CONFIG = 78		# configuration DEFER

    EXITCODE_DEFER = EX_TEMPFAIL
    EXITCODE_REJECT = EX_NOPERM
    EXITCODE_DELIVERED = 0
  end

end

