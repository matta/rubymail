#!/usr/bin/env ruby
#
#   Copyright (c) 2001 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

$SAFE = 1
require 'mail/lda'

begin
  Dir.chdir			# get to home directory
  Mail::LDA.process(STDIN, ".rdeliver_log") { |lda|
    # FIXME: find a better way to pass the lda to .rdeliver
    $lda = lda
    dot_rdeliver = File.join(Dir.pwd, ".rdeliver").untaint
    load(dot_rdeliver)
  }
rescue Mail::LDA::DeliveryStatus => exception
  exit(Mail::LDA.exitcode(exception))
end

  



