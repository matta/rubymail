=begin
   Copyright (C) 2001, 2002 Matt Armstrong.  All rights reserved.

   Permission is granted for use, copying, modification, distribution,
   and distribution of modified versions of this work as long as the
   above copyright notice is included.
=end

require 'mail/message'
require 'mail/deliver'
require 'mail/mta'
require 'mail/parser'

module Mail

  # The <tt>Mail::LDA</tt> class allows flexible delivery of a mail
  # message to a mailbox.  It is designed to make mail filtering
  # scripts easy to write, by allowing the filter author to
  # concentrate on the filter logic and not the particulars of the
  # message or folder format.
  #
  # It is designed primarily to work as an LDA (local delivery agent)
  # for an SMTP server.  It should work well as the basis for a script
  # run from a <tt>.forward</tt> or <tt>.qmail</tt> file.
  class LDA
    include Mail::Deliver

    # A DeliveryComplete exception is one that indicates that
    # Mail::LDA's delivery process is now complete and.  The
    # DeliveryComplete exception is never thrown itself, but its
    # various subclasses are.
    class DeliveryComplete < StandardError
      # Create a new DeliveryComplete exception with a given +message+.
      def initialize(message)
	super
      end
    end

    # This exception is raised when there is a problem logging.
    class LoggingError < StandardError
      attr_reader :original_exception
      def initialize(message, original_exception = nil)
	super(message)
	@original_exception = original_exception
      end
    end

    # Raised when the command run by #pipe fails.
    class DeliveryPipeFailure < DeliveryComplete
      # This is the exit status of the pipe command.
      attr_reader :status
      def initialize(message, status)
	super(message)
	@status = status
      end
    end

    # Raised upon delivery success, unless the +continue+ flag of the
    # <tt>Mail::LDA</tt> delivery method was set to true.
    class DeliverySuccess < DeliveryComplete
      def initialize(message)
	super
      end
    end

    # Raised by <tt>Mail::LDA#reject</tt>.
    class DeliveryReject < DeliveryComplete
      def initialize(message)
	super
      end
    end

    # Raised by <tt>Mail::LDA#defer</tt>.
    class DeliveryDefer < DeliveryComplete
      def initialize(message)
	super
      end
    end

    # Create a new <tt>Mail::LDA</tt> object.
    #
    # +input+ may be a <tt>Mail::Message</tt> object (in which case,
    # it is used directly).  Otherwise, it is passed to
    # <tt>Mail::Message.new</tt> and used to create a new
    # <tt>Mail::Message</tt> object.
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
		   Mail::Parser.new.parse(input)
		 end
      @logging_level = 2
    end

    # Save this message to mail folder.  +folder+ must be the file
    # name of the mailbox.  If +folder+ ends in a slash (/) then the
    # mailbox will be considered to be in Maildir format, otherwise it
    # will be a Unix mbox folder.
    #
    # If +continue+ is false (the default), a
    # <tt>Mail::LDA::DeliverySuccess</tt> exception is raised upon
    # successful delivery.  Otherwise, the method simply returns upon
    # successful delivery.
    #
    # Upon failure to deliver, the function raises a
    # <tt>Mail::LDA::DeliveryPipeFailure</tt> exception.
    #
    # See also: <tt>Mail::Deliver.deliver_mbox</tt> and
    # <tt>Mail::Deliver.deliver_maildir</tt>.
    def save(folder, continue = false)
      log(2, "Action: save to #{folder.inspect}")
      retval = if folder =~ %r{(.*[^/])/$}
                 deliver_maildir($1, @message)
               else
                 deliver_mbox(folder, @message)
               end
      raise DeliverySuccess, "saved to mbox #{folder.inspect}" unless continue
      retval
    end

    # Reject this message.  Logs the +reason+ for the rejection and
    # raises a <tt>Mail::LDA::DeliveryReject</tt> exception.
    def reject(reason)
      log(2, "Action: reject: " + reason)
      raise DeliveryReject.new(reason)
    end

    # Reject this message for now, but request that it be queued for
    # re-delivery in the future.  Logs the +reason+ for the rejection
    # and raises a <tt>Mail::LDA::DeliveryDefer</tt> exception.
    def defer(reason)
      log(2, "Action: defer: " + reason)
      raise DeliveryDefer.new(reason)
    end

    # Pipe this message to a command.  +command+ must be a string
    # specifying a command to pipe the message to.
    #
    # If +continue+ is false, then a successful delivery to the pipe
    # will raise a <tt>Mail::LDA::DeliverySuccess</tt> exception.  If
    # +continue+ is true, then a successful delivery will simply
    # return.  Regardless of +continue+, a failure to deliver to the
    # pipe will raise a <tt>Mail::LDA::DeliveryPipeFailure</tt>
    # exception.
    #
    # See also: <tt>Mail::Deliver.deliver_pipe.</tt>
    def pipe(command, continue = false)
      log(2, "Action: pipe to #{command.inspect}")
      deliver_pipe(command, @message)
      if $? != 0
	m = "pipe failed for command #{command.inspect}"
	raise DeliveryPipeFailure.new(m, $?)
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
      if level <= 0 and @logfile.nil?
	raise LoggingError, "failed to log high priority message: #{str}"
      end
      return if @logfile.nil? or level > @logging_level
      begin
	@logfile.flock(File::LOCK_EX)
	@logfile.print(Time.now.strftime("%Y/%m/%d %H:%M:%S "))
	@logfile.print(sprintf("%05d: ", Process.pid))
	@logfile.puts(str)
	@logfile.flush
	@logfile.flock(File::LOCK_UN)
      rescue
	# FIXME: this isn't tested
	raise LoggingError.new("failed to log message: #{str}", $!)
      end
    end

    # Return the current logging level.
    #
    # See also: #logging_level=, #log
    def logging_level
      @logging_level
    end

    # Set the current logging level.  The +level+ must be a number no
    # less than one.
    #
    # See also: #logging_level, #log
    def logging_level=(level)
      level = Integer(level)
      raise ArgumentError, "invalid logging level value #{level}" if level < 1
      @logging_level = level
    end

    # Return the <tt>Mail::Message</tt> object associated with this
    # <tt>Mail::LDA</tt>.
    #
    # See also: #header, #body
    def message
      @message
    end

    # Sets the message (which should be a Mail::Message object) that
    # we're delivering.
    def message=(message)
      @message = message
    end

    # Return the header of the message as a <tt>Mail::Header</tt> object.
    # This is short hand for <tt>lda.message.header</tt>.
    #
    # See also: #message, #body
    def header
      @message.header
    end

    # Return the body of the message as an array of strings.  This is
    # short hand for <tt>lda.message.body</tt>.
    #
    # See also: #message, #header
    def body
      @message.body
    end

    class << self

      # Takes the same input as #new, but passes the created
      # <tt>Mail::LDA</tt> to the supplied block.  The idea is that
      # the entire delivery script is contained within the block.
      #
      # This function tries to log exceptions that aren't
      # DeliveryComplete exceptions to the lda's log.  If it can log
      # them, it defers the delivery.  But if it can't, it re-raises
      # the exception so the caller can more properly deal with the
      # exception.
      #
      # Expected use:
      #
      #  begin
      #    Mail::LDA.process(stdin, "my-log-file") { |lda|
      #      # ...code uses lda to deliver mail...
      #    }
      #  rescue Mail::LDA::DeliveryComplete => exception
      #    exit(Mail::LDA.exitcode(exception))
      #  rescue Exception
      #    ... perhaps log the exception to a hard coded file ...
      #    exit(Mail::MTA::EX_TEMPFAIL)
      #  end
      def process(input, logfile)
	begin
	  lda = Mail::LDA.new(input, logfile)
	  yield lda
	  lda.defer("finished without a final delivery")
	rescue Exception => exception
	  if exception.class <= DeliveryComplete
	    raise exception
	  else
	    begin
	      lda.log(0, "uncaught exception: " + exception.inspect)
	      lda.log(0, "uncaught exception backtrace:\n    " +
		      exception.backtrace.join("\n    "))
	      lda.defer("uncaught exception")
	    rescue Exception
	      if $!.class <= DeliveryComplete
		# The lda.defer above will generate this, just re-raise
		# the delivery status exception.
		raise
	      else
		# Any errors logging in the uncaught exception and we
		# just re-raise the original exception
		raise exception
	      end
	    end
	  end
	end
      end

      # This function expects the +exception+ argument to be a
      # Mail::LDA::DeliveryComplete subclass.  The function will return
      # the appropriate exitcode that the process should exit with.
      def exitcode(exception)
	case exception
	when DeliverySuccess
	  Mail::MTA::EXITCODE_DELIVERED
	when DeliveryReject
	  Mail::MTA::EXITCODE_REJECT
	when DeliveryComplete
	  Mail::MTA::EXITCODE_DEFER
	else
	  raise ArgumentError,
	    "argument is not a DeliveryComplete exception: " +
	    "#{exception.inspect} (#{exception.type})"
	end
      end

    end

  end
end

