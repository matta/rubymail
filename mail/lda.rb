#!/usr/bin/env ruby
#
#   Copyright (c) 2001 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

require 'mail/message'
require 'mail/deliver'

module Mail
  class LDA
    include Mail::Deliver
    
    def initialize(input = $<, logfile = ".mail_log")
      @logfile = File.open(logfile, File::CREAT|File::APPEND|File::WRONLY,
			   0600) unless logfile.nil?
      @message = Mail::Message.new(input)
      @loglevel = 2
      log(2, "-----------------------------------------------")
      log(2, "From: " + nil_to_s(@message.header.get('from')))
      log(2, "To: " + nil_to_s(@message.header.get('to')))
      log(2, "Subject: " + nil_to_s(@message.header.get('subject')))
    end
    
    def save(folder, continue = nil)
      log(2, "Action: save to #{folder}")
      deliver_mbox(folder, @message)
      exit 0 unless continue
    end

    def reject()
      log(2, "Action: reject")
      exit(77)			# EX_NOPERM
    end

    def defer()
      log(2, "Action: defer")	# EX_TEMPFAIL
      exit(75)
    end

    def pipe(continue = nil)
      raise "not implemented"
    end

    def log(priority, str)
      return unless priority <= @loglevel
      return if @logfile.nil?
      @logfile.flock(File::LOCK_EX)
      @logfile.print(Time.now.strftime("%Y/%m/%d %H:%M:%S "))
      @logfile.print(sprintf("%05d: ", Process.pid))
      @logfile.puts(str)
      @logfile.flush
      @logfile.flock(File::LOCK_UN)
    end

    attr :message

    def header
      @message.header
    end
    def body
      @message.body
    end
    def get(*args)
      @message.header.get(*args)
    end
    
    private

    def nil_to_s(s)
      if s.nil? then "" else s end
    end
  end
end

