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
  # The Mail::LDA class allows flexible delivery of a mail message to
  # a mailbox.  It is designed to make mail filtering scripts easy to
  # write, by allowing the filter author to concentrate on the filter
  # logic and not the particulars of the message for folder format.
  #
  # It is designed primarily to work as an LDA (local delivery agent)
  # for an SMTP server.  It should work well as the basis for a script
  # run from a <tt>.forward</tt> or <tt>.qmail</tt> file.
  class LDA
    include Mail::Deliver

    # A base class for delivery status exceptions.
    class DeliveryStatus < StandardError

      # Read the exit status of the external command (if any) that
      # generated this delivery status exception.
      attr_reader :status

      # Create a new DeliveryStatus exception with a given message and
      # status
      def initialize(message, status)
	@status = status
	@failed = status != 0
	super(message)
      end

      # Check if the external command (if any) that generated this
      # delivery status exception failed or not.
      def failed?
	@failed
      end
    end

    # Raised upon delivery failure of any kind.
    class DeliveryFailure < DeliveryStatus
      def initialize(message, status)
	super
      end
    end

    # Raised upon delivery success, unless the +continue+ flag of the
    # Mail::LDA delivery method was set to true.
    class DeliverySuccess < DeliveryStatus
      def initialize(message)
	super(message, 0)
      end
    end

    # Create a new Mail::LDA object.
    #
    # +input+ may be a Mail::Message object (in which case, it is used
    # directly).  Otherwise, it is passed to Mail::Message#new and
    # used to create a new Mail::Message object.
    #
    # +log+ may be nil (to disable logging completely) or a file name
    # to which log messages will be appended.
    def initialize(input, logfile)
      @logfile =
	if logfile.nil?
	  nil
	else
	  File.open(logfile, File::CREAT|File::APPEND|File::WRONLY, 0600)
	end
      @message = if input.is_a?(Mail::Message)
		   input
		 else
		   Mail::Message.new(input)
		 end
      @logging_level = 2
      log(2, "-----------------------------------------------")
      log(2, "From: " + @message.header.get('from').to_s)
      log(2, "To: " + @message.header.get('to').to_s)
      log(2, "Subject: " + @message.header.get('subject').to_s)
    end

    # Save this message to a Unix mbox folder.  +folder+ must be the
    # file name of the mailbox.
    #
    # FIXME: catch all errors in deliver_mbox and raise
    # DeliveryFailure?
    #
    # FIXME: describe how this function behaves with respect to
    # continue
    def save(folder, continue = false)
      log(2, "Action: save to #{folder}")
      deliver_mbox(folder, @message)
      raise DeliverySuccess, "saved to mbox #{folder.inspect}" unless continue
    end

    # Reject this message, causing a bounce.
    #
    # FIXME: these should raise a DeliveryReject exception.
    def reject()
      log(2, "Action: reject")
      exit(77)			# EX_NOPERM
    end

    # Reject this message for now, but request that it be queued
    # for re-delivery in the future.
    #
    # FIXME: explain that this depends on the SMTP server.
    #
    # FIXME: this should raise a DeliveryDefer exception.
    def defer()
      log(2, "Action: defer")	# EX_TEMPFAIL
      exit(75)
    end

    # Pipe this message to a command.  +command+ must be a string
    # specifying a command to pipe the message to.
    #
    # If +continue+ is false, then a successful delivery to the pipe
    # will raise a DeliverySuccess exception.  If +continue+ is true,
    # then a successful delivery will simply return.  Regardless of
    # +continue+, a failure to deliver to the pipe will raise a
    # DeliveryFailure exception.
    #
    # See also: Mail::Deliver#deliver_pipe.
    def pipe(command, continue = false)
      log(2, "Action: pipe to #{command.inspect}")
      deliver_pipe(command, @message)
      if $? != 0
	message = "pipe failed for command #{command.inspect}"
	raise DeliveryFailure.new(message, $?)
      end
      unless continue
	raise DeliverySuccess.new("pipe to #{command.inspect}")
      end
    end

    # Log a string to the log.  If the current log is nil or +level+
    # is greater than the current logging level, then the string will
    # not be logged.
    #
    # See also #logging_level, #logging_level=
    def log(level, str)
      return if @logfile.nil? or level > @logging_level
      @logfile.flock(File::LOCK_EX)
      @logfile.print(Time.now.strftime("%Y/%m/%d %H:%M:%S "))
      @logfile.print(sprintf("%05d: ", Process.pid))
      @logfile.puts(str)
      @logfile.flush
      @logfile.flock(File::LOCK_UN)
    end

    # Return the current logging level.
    #
    # See also: #log
    #
    # FIXME: unit test this
    def logging_level
      @logging_level
    end

    # Set the current logging level.  The +level+ must be an Integer
    # or convertible to one.
    #
    # FIXME: unit test this (non integer args throw exceptions)
    def logging_level=(level)
      @logging_level = Integer(level)
    end

    # Return the Mail::Message object.
    def message
      @message
    end

    # Return the header of the message as a Mail::Header object.  This
    # is short hand for <tt>lda.message.header</tt>.
    def header
      @message.header
    end
    
    # Return the body of the message as an array of strings.  This is
    # short hand for <tt>lda.message.body</tt>.
    def body
      @message.body
    end
  end
end

