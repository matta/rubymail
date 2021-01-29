=begin
   Copyright (C) 2001, 2002 Matt Armstrong.  All rights reserved.

   Permission is granted for use, copying, modification, distribution,
   and distribution of modified versions of this work as long as the
   above copyright notice is included.
=end

# Comment for Mail module
module Mail

  # This class provides the following functionality:
  #
  # * Parses RFC2822 address lists into a list of Address
  #   objects (see #parse).
  #
  # * Format Address objects as appropriate for insertion into email
  #   messages (see #format).
  #
  # * Allows manipulation of the various parts of the address (see
  #   #local=, #domain=, #display_name=, #comments=).
  class Address

    ATEXT = '[\w=!#$%&\'*+-?^\`{|}~]+'

    # Create a new address.  If the +string+ argument is not nil, it
    # is parsed for mail addresses and if one is found, it is used to
    # initialize this object.
    #
    # See mail/deliver.rb
    def initialize(string = nil)

      @local = @domain = @comments = @display_name = nil

      if string.kind_of?(String)
	addrs = Address.parse(string)
	if addrs.length > 0
	  @local = addrs[0].local
	  @domain = addrs[0].domain
	  @comments = addrs[0].comments
	  @display_name = addrs[0].display_name
        end
      else
	raise ArgumentError unless string.nil?
      end
    end

    # Retrieve the local portion of the mail address.  This is the
    # portion that precedes the <tt>@</tt> sign.
    def local
      @local
    end

    # Assign the local portion of the mail address.  This is the
    # portion that precedes the <tt>@</tt> sign.
    def local=(l)
      raise ArgumentError unless l.nil? || l.kind_of?(String)
      @local = l
    end

    # Returns the display name of this address.  The display name is
    # present only for "angle addr" style addresses such as:
    #
    #	John Doe <johnd@example.net>
    #
    # In this case, the display name will be "John Doe".  In
    # particular this old style address has no display name:
    #
    #	bobs@example.net (Bob Smith)
    #
    # See also display_name=, #name
    def display_name
      @display_name
    end

    # Assign a display name to this address.  See display_name for a
    # definition of what this is.
    #
    # See also display_name
    def display_name=(str)
      unless str.nil? || str.kind_of?(String)
        raise ArgumentError, 'not a string'
      end
      @display_name = str
      @display_name = nil if @display_name == ''
    end

    # Returns a best guess at a display name for this email address.
    # This function first checks if the address has a true display
    # name (see display_name) and returns it if so.  Otherwise, if the
    # address has any comments, the last comment will be returned.
    #
    # In most cases, this will behave reasonably.  For example, it
    # will return "Bob Smith" for this address:
    #
    #	bobs@example.net (Bob Smith)
    #
    # See also display_name, #comments, #comments=
    def name
      @display_name || (@comments && @comments.last)
    end

    # Returns the comments in this address as an array of strings.
    def comments
      @comments
    end

    # Set the comments for this address.  The +comments+ argument can
    # be a string, or an array of strings.  In either case, any
    # existing comments are replaced.
    #
    # See also #comments, #name
    def comments=(comments)
      @comments = comments
      @comments.freeze
    end

    # Retrieve to the domain portion of the mail address.  This is the
    # portion after the <tt>@</tt> sign.
    def domain
      @domain
    end

    # Assign a domain name to this address.  This is the portion after
    # the <tt>@</tt> sign.  Any existing domain name will be changed.
    def domain=(domain)
      @domain = if domain.nil? or domain == ''
		  nil
		else
                  raise ArgumentError unless domain.kind_of?(String)
		  domain.strip
		end
    end

    # Returns the email address portion of the address (i.e. without a
    # display name, angle addresses, or comments).
    #
    # The string returned is not suitable for insertion into an
    # e-mail.  RFC2822 quoting rules are not followed.  The raw
    # address is returned instead.
    #
    # For example, if the local part requires quoting, this function
    # will not perform the quoting (see #format for that).  So this
    # function can returns strings such as:
    #
    #  "address with no quoting@example.net"
    #
    # See also #format
    def address
      if @domain.nil?
	@local
      else
	@local + '@' + @domain
      end
    end

    # Return this address as a String formated as appropriate for
    # insertion into a mail message.
    def format
      display_name = if @display_name.nil?
		       nil
		     elsif @display_name =~ /^[-\/\w=!#\$%&'*+?^`{|}~ ]+$/
		       @display_name
		     else
		       '"' + @display_name.gsub(/["\\]/, '\\\\\&') + '"'
		     end
      local = if (@local !~ /^[-\w=!#\$%&'*+?^`{|}~\.\/]+$/ ||
		  @local =~ /^\./ ||
		  @local =~ /\.$/ ||
		  @local =~ /\.\./)
		'"' + @local.gsub(/["\\]/, '\\\\\&') + '"'
	      else
		@local
	      end
      domain = if (!@domain.nil? and
		   (@domain !~ /^[-\w=!#\$%&'*+?^`{|}~\.\/]+$/ ||
		    @domain =~ /^\./ ||
		    @domain =~ /\.$/ ||
		    @domain =~ /\.\./))
	       then
		 '[' + if @domain =~ /^\[(.*)\]$/
			 $1
		       else
			 @domain
		       end.gsub(/[\[\]\\]/, '\\\\\&') + ']'
	       else
		 @domain
	       end
      address = if domain.nil?
		  local
		elsif !display_name.nil? or domain[-1] == ?]
		  '<' + local + '@' + domain + '>'
		else
		  local + '@' + domain
		end
      comments = nil
      comments = unless @comments.nil?
		   @comments.collect { |c|
	  '(' + c.gsub(/[()\\]/, '\\\\\&') + ')'
	}.join(' ')
		 end
      [display_name, address, comments].compact.join(' ')
    end

    # This class provides a facility to parse a string containing one
    # or more RFC2822 addresses into an array of Mail::Address
    # objects.  You can use it directly, but it is more conveniently
    # used with the Mail::Address.parse method.
    class Parser

      # Create a Mail::Address::Parser object that will parse
      # +string+.  See also the Mail::Address.parse method.
      def initialize(string)
        @string = string
      end

      # This function attempts to extract mailing addresses from the
      # string passed to #new.  The function returns an array of
      # Mail::Address objects.  A malformed input string will not
      # generate an exception.  Instead, the array returned will
      # simply not contained the malformed addresses.
      #
      # The string is expected to be in a valid format as documented
      # in RFC2822's mailbox-list grammar.  This will work for lists
      # of addresses in the <tt>To:</tt>, <tt>From:</tt>, etc. headers
      # in email.
      def parse
        @lexemes = []
	@tokens = []
	@addresses = []
	@errors = 0
	new_address
        get
        address_list
	reset_errors
	@addresses.delete_if { |a|
	  !a.local || !a.domain
	}
      end

      private

      SYM_ATOM = :atom
      SYM_QTEXT = :qtext
      SYM_COMMA = :comma
      SYM_LESS_THAN = :less_than
      SYM_GREATER_THAN = :greater_than
      SYM_AT_SIGN = :at_sign
      SYM_PERIOD = :period
      SYM_COLON = :colon
      SYM_SEMI_COLON = :semi_colon
      SYM_DOMAIN_LITERAL = :domain_literal

      def reset_errors
	if @errors > 0
	  @addresses.pop
	  @errors = 0
	end
      end

      def new_address
	reset_errors
	@addresses.push(Address.new)
      end

      # Get the text that has been saved up to this point.
      def get_text
        text = ''
        sep = ''
        @lexemes.each { |lexeme|
          if lexeme == '.'
            text << lexeme
            sep = ''
          else
            text << sep
            text << lexeme
            sep = ' '
          end
        }
	@lexemes = []
        text
      end

      # Save the current lexeme away for later retrieval with
      # get_text.
      def save_text
        @lexemes << @lexeme
      end

      # Parse this:
      # address_list = ([address] SYNC ",") {[address] SYNC "," } [address] .
      def address_list
	if @sym == SYM_ATOM ||
	    @sym == SYM_QTEXT ||
	    @sym == SYM_LESS_THAN
	  address
	end
	sync(SYM_COMMA)
	return if @sym.nil?
	expect(SYM_COMMA)
	new_address
        while @sym == SYM_ATOM ||
            @sym == SYM_QTEXT ||
            @sym == SYM_COMMA ||
            @sym == SYM_LESS_THAN
	  if @sym == SYM_ATOM || @sym == SYM_QTEXT || @sym == SYM_LESS_THAN
	    address
	  end
	  sync(SYM_COMMA)
	  return if @sym.nil?
	  expect(SYM_COMMA)
	  new_address
        end
        if @sym == SYM_ATOM || @sym == SYM_QTEXT || @sym == SYM_LESS_THAN
          address
        end
      end

      # Parses ahead through a local-part or display-name until no
      # longer looking at a word or "." and returns the next symbol.
      def address_lookahead
	lookahead = []
	while @sym == SYM_ATOM || @sym == SYM_QTEXT || @sym == SYM_PERIOD
	  lookahead.push([@sym, @lexeme])
	  get
	end
	retval = @sym
	putback(@sym, @lexeme)
	putback_array(lookahead)
	get
	retval
      end

      # Parse this:
      # address = mailbox | group
      def address
        # At this point we could be looking at a display-name, angle
        # addr, or local-part.  If looking at a local-part, it could
        # actually be a display-name, according to the following:
        #
        # local-part '@' -> it is a local part of a local-part @ domain
        # local-part '<' -> it is a display-name of a mailbox
        # local-part ':' -> it is a display-name of a group
        # display-name '<' -> it is a mailbox display name
        # display-name ':' -> it is a group display name
        #

	# set lookahead to '@' '<' or ':' (or another value for
	# invalid input)
	lookahead = address_lookahead

	if lookahead == SYM_COLON
	  group
	else
	  mailbox(lookahead)
	end
      end

      # Parse this:
      #  mailbox = angleAddr |
      #            word {word | "."} angleAddr |
      #            word {"." word} "@" domain .
      #
      # lookahead will be set to the return value of
      # address_lookahead, which will be '@' or '<' (or another value
      # for invalid input)
      def mailbox(lookahead)
        if @sym == SYM_LESS_THAN
          angle_addr
        elsif lookahead == SYM_LESS_THAN
          word
          while @sym == SYM_ATOM || @sym == SYM_QTEXT || @sym == SYM_PERIOD
            if @sym == SYM_ATOM || @sym == SYM_QTEXT
              word
            else
	      save_text
              get
            end
          end
	  @addresses.last.display_name = get_text
          angle_addr
        else
          word
          while @sym == SYM_PERIOD
            save_text
            get
            word
          end
	  @addresses.last.local = get_text
          expect(SYM_AT_SIGN)
          domain
        end
      end

      # Parse this:
      #   group = word {word | "."} SYNC ":" [mailbox_list] SYNC ";"
      def group
        word
        while @sym == SYM_ATOM || @sym == SYM_QTEXT || @sym == SYM_PERIOD
          if @sym == SYM_ATOM || @sym == SYM_QTEXT
            word
          else
	    save_text
            get
          end
        end
        sync(SYM_COLON)
	expect(SYM_COLON)
	get_text		# throw away group name
	@addresses.last.comments = nil
        if @sym == SYM_ATOM || @sym == SYM_QTEXT ||
	    @sym == SYM_COMMA || @sym == SYM_LESS_THAN
          mailbox_list
        end
        sync(SYM_SEMI_COLON)
	expect(SYM_SEMI_COLON)
      end

      # Parse this:
      #   word = atom | quotedString
      def word
        if @sym == SYM_ATOM || @sym == SYM_QTEXT
          save_text
          get
        else
	  error "expected word, got #{@sym.inspect}"
	end
      end

      # Parse a mailbox list.
      def mailbox_list
	mailbox(address_lookahead)
	while @sym == SYM_COMMA
	  get
	  new_address
	  mailbox(address_lookahead)
	end
      end

      # Parse this:
      #   angleAddr = SYNC "<" [obsRoute] addrSpec SYNC ">"
      def angle_addr
        expect(SYM_LESS_THAN)
        if @sym == SYM_AT_SIGN
          obs_route
        end
        addr_spec
        expect(SYM_GREATER_THAN)
      end

      # Parse this:
      #   domain = domainLiteral | obsDomain
      def domain
        if @sym == SYM_DOMAIN_LITERAL
	  save_text
	  @addresses.last.domain = get_text
	  get
        elsif @sym == SYM_ATOM
          obs_domain
	  @addresses.last.domain = get_text
	else
	  error "expected start of domain, got #{@sym.inspect}"
	end
      end

      # Parse this:
      #   addrSpec = localPart "@" domain
      def addr_spec
        local_part
        expect(SYM_AT_SIGN)
        domain
      end

      # Parse this:
      #   local_part = word *( "." word )
      def local_part
        word
        while @sym == SYM_PERIOD
	  save_text
          get
          word
        end
	@addresses.last.local = get_text
      end

      # Parse this:
      #   obs_domain =  atom  *( "."  atom ) .
      def obs_domain
        expect_save(SYM_ATOM)
        while @sym == SYM_PERIOD
	  save_text
          get
          expect_save(SYM_ATOM)
        end
      end

      # Parse this:
      #   obs_route = obs_domain_list ":"
      def obs_route
        obs_domain_list
        expect(SYM_COLON)
      end

      # Parse this:
      #   obs_domain_list = "@" domain *( *( "," ) "@" domain )
      def obs_domain_list
        expect(SYM_AT_SIGN)
        domain
        while @sym == SYM_COMMA || @sym == SYM_AT_SIGN
          while @sym == SYM_COMMA
            get
          end
          expect(SYM_AT_SIGN)
          domain
        end
      end

      # Put a token back into the input stream.  This token will be
      # retrieved by the next call to get.
      def putback(sym, lexeme)
	@tokens.push([sym, lexeme])
      end

      # Put back an array of tokens into the input stream.
      def putback_array(a)
	a.reverse_each { |e|
	  putback(*e)
	}
      end

      # Get a single token from the string or from the @tokens array
      # if somebody used putback.
      def get
	unless @tokens.empty?
	  @sym, @lexeme = @tokens.pop
	else
	  get_tokenize
	end
      end

      # Get a single token from the string
      def get_tokenize
        @lexeme = nil
        loop {
          case @string
	  when nil		# the end
	    @sym = nil
	    break
          when ""               # the end
            @sym = nil
            break
          when /\A[\r\n\t ]+/m	# skip whitespace
            @string = $'
          when /\A\(/m          # skip comment
            comment
          when /\A""/           # skip empty quoted text
            @string = $'
          when /\A[\w!$%&\'*+\/=?^_\`{\}|~#-]+/m
            @string = $'
            @sym = SYM_ATOM
            break
          when /\A"(.*?([^\\]|\\\\))"/m
            @string = $'
            @sym = SYM_QTEXT
            @lexeme = $1.gsub(/\\(.)/, '\1')
            break
          when /\A</
            @string = $'
            @sym = SYM_LESS_THAN
            break
          when /\A>/
            @string = $'
            @sym = SYM_GREATER_THAN
            break
          when /\A@/
            @string = $'
            @sym = SYM_AT_SIGN
            break
          when /\A,/
            @string = $'
            @sym = SYM_COMMA
            break
          when /\A:/
            @string = $'
            @sym = SYM_COLON
            break
          when /\A;/
            @string = $'
            @sym = SYM_SEMI_COLON
            break
          when /\A\./
            @string = $'
            @sym = SYM_PERIOD
            break
	  when /\A(\[.*?([^\\]|\\\\)\])/m
	    @string = $'
	    @sym = SYM_DOMAIN_LITERAL
	    @lexeme = $1.gsub(/(^|[^\\])[\r\n\t ]+/, '\1').gsub(/\\(.)/, '\1')
	    break
          when /\A./
            @string = $'	# garbage
	    error('garbage character in string')
          else
            raise "internal error, @string is #{@string.inspect}"
          end
        }
        if @sym
          @lexeme ||= $&
        end
      end

      def comment
        depth = 0
        comment = ''
        catch(:done) {
          while @string =~ /\A(\(([^\(\)\\]|\\.)*)/m
            @string = $'
            comment += $1
            depth += 1
            while @string =~ /\A(([^\(\)\\]|\\.)*\))/m
              @string = $'
              comment += $1
              depth -= 1
              throw :done if depth == 0
              if @string =~ /\A(([^\(\)\\]|\\.)+)/
                @string = $'
                comment += $1
              end
            end
          end
        }
        comment = comment.gsub(/[\r\n\t ]+/m, ' ').
          sub(/\A\((.*)\)$/m, '\1').
          gsub(/\\(.)/, '\1')
	@addresses.last.comments =
	  (@addresses.last.comments || []) + [comment]
      end

      def expect(token)
        if @sym == token
          get
	else
	  error("expected #{token.inspect} but got #{@sym.inspect}")
	end
      end

      def expect_save(token)
        if @sym == token
	  save_text
	end
	expect(token)
      end

      def sync(token)
        while @sym && @sym != token
	  error "expected #{token.inspect} but got #{@sym.inspect}"
          get
        end
      end

      def error(s)
	@errors += 1
      end
    end

    # Given a string, this function attempts to extract mailing
    # addresses from it and returns an array of those addresses.
    #
    # This is identical to using a Mail::Address::Parser directly like
    # this:
    #
    #  Mail::Address::Parser.new(string).parse
    def Address.parse(string)
      Parser.new(string).parse
    end

  end
end

if $0 == __FILE__
  parser = Mail::Address::Parser.new('A Group:a@b.c,d@e.f;')
  p parser.parse
end
