#--
#   Copyright (C) 2001, 2002, 2003, 2008 Matt Armstrong.  All rights
#   reserved.
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
#++
# Implements the RMail::Address, RMail::Address::List, and
# RMail::Address::Parser classes.  Together, these classes allow you
# to robustly parse, manipulate, and generate RFC2822 email addresses
# and address lists.

module RMail

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

    # Compare this address with another based on the email address
    # portion only (any display name and comments are ignored).  If
    # the other object is not an RMail::Address, it is coerced into a
    # string with its to_str method and then parsed into an
    # RMail::Address object.
    def <=>(other)
      if !other.kind_of?(RMail::Address)
	other = RMail::Address.new(other.to_str)
      end
      cmp = (@local || '') <=> (other.local || '')
      if cmp == 0
        cmp = (@domain || '') <=> (other.domain || '')
      end
      return cmp
    end
    include Comparable

    # Return a hash value for this address.  This is based solely on
    # the email address portion (any display name and comments are
    # ignored).
    def hash
      address.hash
    end

    # Return true if the two objects are equal.  Do this based solely
    # on the email address portion (any display name and comments are
    # ignored).  Fails if the other object is not an RMail::Address
    # object.
    def eql?(other)
      raise TypeError unless other.kind_of?(RMail::Address)
      @local.eql?(other.local) and @domain.eql?(other.domain)
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
      case comments
      when nil
        @comments = comments
      when Array
        @comments = comments
      when String
        @comments = [ comments ]
      else
        raise TypeError, "Argument to RMail::Address#comments= must be " +
          "String, Array or nil, was #{comments.type}."
      end
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

    # Addresses can be converted into strings.
    alias :to_str :format

    # This class provides a facility to parse a string containing one
    # or more RFC2822 addresses into an array of RMail::Address
    # objects.  You can use it directly, but it is more conveniently
    # used with the RMail::Address.parse method.
    class Parser

      # Create a RMail::Address::Parser object that will parse
      # +string+.  See also the RMail::Address.parse method.
      def initialize(string)
        @string = string
      end

      # This function attempts to extract mailing addresses from the
      # string passed to #new.  The function returns an
      # RMail::Address::List of RMail::Address objects
      # (RMail::Address::List is a subclass of Array).  A malformed
      # input string will not generate an exception.  Instead, the
      # array returned will simply not contained the malformed
      # addresses.
      #
      # The string is expected to be in a valid format as documented
      # in RFC2822's mailbox-list grammar.  This will work for lists
      # of addresses in the <tt>To:</tt>, <tt>From:</tt>, etc. headers
      # in email.
      def parse
        @lexemes = []
	@tokens = []
	@addresses = RMail::Address::List.new
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
      SYM_ATOM_NON_ASCII = :atom_non_ascii
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
            @sym == SYM_ATOM_NON_ASCII ||
	    @sym == SYM_QTEXT ||
	    @sym == SYM_LESS_THAN
	  address
	end
	sync(SYM_COMMA)
	return if @sym.nil?
	expect(SYM_COMMA)
	new_address
        while @sym == SYM_ATOM ||
            @sym == SYM_ATOM_NON_ASCII ||
            @sym == SYM_QTEXT ||
            @sym == SYM_LESS_THAN ||
            @sym == SYM_COMMA
	  if @sym == SYM_ATOM ||
              @sym == SYM_ATOM_NON_ASCII ||
              @sym == SYM_QTEXT ||
              @sym == SYM_LESS_THAN
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
	while @sym == SYM_ATOM ||
            @sym == SYM_ATOM_NON_ASCII ||
            @sym == SYM_QTEXT ||
            @sym == SYM_PERIOD
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
          display_name_word
          while @sym == SYM_ATOM ||
              @sym == SYM_ATOM_NON_ASCII ||
              @sym == SYM_QTEXT ||
              @sym == SYM_PERIOD
            if @sym == SYM_ATOM ||
                @sym == SYM_ATOM_NON_ASCII ||
                @sym == SYM_QTEXT
              display_name_word
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

          if @sym == SYM_LESS_THAN
            # Workaround for invalid input.  Treat 'foo@bar <foo@bar>' as if it
            # were '"foo@bar" <foo@bar>'.  The domain parser will eat
            # 'bar' but stop at '<'.  At this point, we've been
            # parsing the display name as if it were an address, so we
            # throw the address into display_name and parse an
            # angle_addr.
            @addresses.last.display_name =
              format("%s@%s", @addresses.last.local, @addresses.last.domain)
            @addresses.last.local = nil
            @addresses.last.domain = nil
            angle_addr
          end
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
      #   word = atom | atom_non_ascii | quotedString
      def display_name_word
        if @sym == SYM_ATOM || @sym == SYM_ATOM_NON_ASCII || @sym == SYM_QTEXT
          save_text
          get
        else
	  error "expected word, got #{@sym.inspect}"
	end
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
          when /\A[\200-\377\w!$%&\'*+\/=?^_\`{\}|~#-]+/nm
            # This is just like SYM_ATOM, but includes all characters
            # with high bits.  This is so we can allow such tokens in
            # the display name portion of an address even though it
            # violates the RFCs.
            @string = $'
            @sym = SYM_ATOM_NON_ASCII
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
    # addresses from it and returns an RMail::Address::List of those
    # addresses (RMail::Address::List is a subclass of Array).
    #
    # This is identical to using a RMail::Address::Parser directly like
    # this:
    #
    #  RMail::Address::Parser.new(string).parse
    def Address.parse(string)
      Parser.new(string).parse
    end

    # RMail::Address::List is a simple subclass of the Array class
    # that provides convenience methods for accessing the
    # RMail::Address objects it contains.
    class List < Array

      # Returns an array of strings -- the result of calling
      # RMail::Address#local on each element of the list.
      def locals
        collect { |a| a.local }
      end

      # Returns an array of strings -- the result of calling
      # RMail::Address#display_name on each element of the list.
      def display_names
        collect { |a| a.display_name }
      end

      # Returns an array of strings -- the result of calling
      # RMail::Address#name on each element of the list.
      def names
        collect { |a| a.name }
      end

      # Returns an array of strings -- the result of calling
      # RMail::Address#domain on each element of the list.
      def domains
        collect { |a| a.domain }
      end

      # Returns an array of strings -- the result of calling
      # RMail::Address#address on each element of the list.
      def addresses
        collect { |a| a.address }
      end

      # Returns an array of strings -- the result of calling
      # RMail::Address#format on each element of the list.
      def format
        collect { |a| a.format }
      end

    end

  end
end

if $0 == __FILE__
  parser = RMail::Address::Parser.new('A Group:a@b.c,d@e.f;')
  p parser.parse
end
