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

      if string.kind_of?(String)
	addrs = Address.parse(string)
	if addrs.length > 0
	  @local = addrs[0].local
	  @domain = addrs[0].domain
	  @comments = addrs[0].comments
	  @display_name = addrs[0].display_name
        else
          @local = @domain = @comments = @display_name = nil
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

    # Given a string, this function attempts to extract mailing
    # addresses from it.  The function returns an array of
    # Mail::Address objects.  A malformed input string will not
    # generate an exception.  Instead, the array returned will be
    # empty.
    #
    # The string is expected to be in a valid format as documented in
    # RFC2822's mailbox-list grammar.  Some commonly seen invalid
    # input is also handled correctly.  This will work for lists of
    # addresses in the <tt>To:</tt>, <tt>From:</tt>, etc. headers in
    # email.
    def Address.parse(string)
      require "English"

      puts "\nparse #{string.inspect}" if $DEBUG

      token_list = tokenize(string)
      puts "token_list #{token_list.inspect}" if $DEBUG

      # Split up each address in the mailbox list
      mailboxes = []
      commas = []
      in_angle = false
      token_list.each_with_index { |token, i|
	if token[0] == :special
	  case token[1]
	  when "<"
	    in_angle = true
	  when ">"
	    in_angle = false
	  when ","
	    commas.push(i) unless in_angle
	  end
	end
      }
      puts "commas #{commas.inspect}" if $DEBUG
      offset = 0
      commas.each { |i|
	mailboxes.push(token_list.slice(0, i - offset))
	token_list.slice!(0, i - offset + 1)
	offset += i - offset + 1
      }
      mailboxes.push(token_list)

      puts "mailboxes #{mailboxes.inspect}" if $DEBUG

      results = []
      mailboxes.each { |tokens|
	puts "## tokens #{tokens.inspect}" if $DEBUG

	# Find any ":" -- a group name
	if colon = tokens.index([:special, ':'])
	  angle = tokens.index([:special, '<'])
	  if angle.nil? || angle > colon
	    tokens.slice!(0 .. tokens.index([:special, ':']))
	  end
	end
	# FIXME: perhaps move this into the above if statement?
	if tokens.index([:special, ";"])
	  tokens.slice!(tokens.index([:special, ";"]))
	end

	# Strip comments
	comments = []
	tokens.delete_if { |token|
	  if token[0] == :comment
	    comments.push(token[1])
	    true
	  end
	}
	comments = nil if comments.empty?

	puts "comments #{comments.inspect}" if $DEBUG
	puts "tokens #{tokens.inspect}" if $DEBUG

	# Find any "<"
	angle_index = tokens.index([:special, "<"])

	unless angle_index.nil?
	  # new style name-addr = [display-name] angle-addr
	  if angle_index > 0
	    display_name = join_tokens_whitespace(tokens[0, angle_index])
	  else
	    display_name = nil
	  end
	  tokens = tokens[angle_index..-1]

	  puts "display_name #{display_name.inspect}" if $DEBUG
	  puts "tokens #{tokens.inspect}" if $DEBUG

	  # Find the ">"
	  angle_index = tokens.index([:special, ">"]) || tokens.length - 1

	  address = tokens[1, angle_index - 1]
	  tokens = tokens[angle_index + 1 .. -1]

	  unless address.nil?
	    if colon = address.rindex([:special, ':'])
	      puts "found obs-domain #{address.inspect}" if $DEBUG
	      address.slice!(0..colon)
	    end
	  end
	  local, domain = split_address(address)
	else
	  # New style addr-spec = local-part @ domain
	  local, domain = split_address(tokens)
	end

	unless local.nil?
	  local = join_tokens(local)
	  unless local == ''
	    puts "new address #{local.inspect} #{domain.inspect} #{comments.inspect}" if $DEBUG
	    ret = Mail::Address.new
	    ret.local = local
	    ret.domain = join_tokens(domain)
	    ret.display_name = display_name
	    ret.comments = comments
	    results.push(ret)
	  end
	end
      }
      puts "parsed #{results.inspect}" if $DEBUG
      return results
    end

    private

    # Turn a string into an array of tokens.  Token types are :atom,
    # :qtext, :domain_literal, and :special.  Each array element
    # consists of a sub-array pair [token, string].
    def Address.tokenize(string)
      puts ">tokenize #{string.inspect}" if $DEBUG
      words = []
      loop {
	case string
	when ""			# the end
	  break
	when /\A[\r\n\t ]+/m	# whitespace
	  puts "see whitespace #{$MATCH.inspect} #{$PREMATCH.inspect}" if $DEBUG
	  string = $POSTMATCH
	when /\A\(/m # comment
	  puts "see comment #{string.inspect}" if $DEBUG
          string = tokenize_comment(string, words)
	when /\A[\w!$%&\'*+\/=?^_\`{\}|~#-]+/m
	  puts "see atom" if $DEBUG
	  string = $POSTMATCH
	  words.push([:atom, $MATCH])
	when /\A""/
	  puts "see empty double quote" if $DEBUG
	  string = $POSTMATCH
	when /\A"(.*?([^\\]|\\\\))"/m
	  puts "see quote" if $DEBUG
	  string = $POSTMATCH
	  words.push([:qtext, $1.gsub(/\\(.)/, '\1')]) unless $1.nil?
	when /\A(\[.*?([^\\]|\\\\)\])/m
	  puts "see domain literal #{$1.inspect}" if $DEBUG
	  string = $POSTMATCH
	  words.push([:domain_literal, $1.gsub(/\\(.)/, '\1')])
	when /\A[<>@,:;\.]/m
	  puts "see literal" if $DEBUG
	  words.push([:special, $MATCH])
	  string = $POSTMATCH
	when /\A./m
	  puts "see weirdness #{$MATCH.inspect}" if $DEBUG
	  string = $POSTMATCH
	end
	puts "last token #{words[-1].inspect}" if $DEBUG
	puts "string #{string.inspect}" if $DEBUG
      }
      puts "<tokenize #{words.inspect}" if $DEBUG
      words
    end

    def Address.tokenize_comment(string, words)
      depth = 0
      comment = ''
      catch(:done) {
        while string =~ /\A(\(([^\(\)\\]|\\.)*)/m
          string = $POSTMATCH
          comment += $1
          depth += 1
          puts "depth #{depth}, comment now #{comment.inspect}, string now #{string.inspect}" if $DEBUG
          while string =~ /\A(([^\(\)\\]|\\.)*\))/m
            string = $POSTMATCH
            comment += $1
            depth -= 1
            puts "depth #{depth}, comment now #{comment.inspect}, string now #{string.inspect}" if $DEBUG
            throw :done if depth == 0
            if string =~ /\A(([^\(\)\\]|\\.)+)/
              string = $POSTMATCH
              comment += $1
              puts "depth #{depth}, comment now #{comment.inspect}, string now #{string.inspect}" if $DEBUG
            end
          end
        end
      }
      words.push([:comment,
                   comment.gsub(/[\r\n\t ]+/m, ' ').
                   sub(/\A\((.*)\)$/m, '\1').
                   gsub(/\\(.)/, '\1')])
      string
    end

    # Delete whitespace tokens from the beginning of array
    # and return it.
    def Address.delete_whitespace_tokens(tokens)
      seen_non_whitespace = false
      tokens.delete_if { |token|
        if seen_non_whitespace || token[0] != :whitespace
          seen_non_whitespace = true
          false
        else
          true
        end
      }
    end

    # Join a token list into a string without ignoring the whitespace.
    def Address.join_tokens_whitespace(tokens)
      joined = ''
      unless tokens.nil?
        tokens = delete_whitespace_tokens(tokens.dup).reverse
        tokens = delete_whitespace_tokens(tokens).reverse
        sep = ''
        tokens.each { |token|
          if token[0] == :whitespace
            if token[1] !~ /[\r\n]/
              sep = token[1]
            end
          else
            if token[0] == :special && (token[1] == '@' || token[1] == '.')
              joined << token[1]
              sep = ''
            else
              joined << sep
              joined << token[1]
              sep = ' '
            end
          end
        }
      end
      joined
    end

    # Join a token list into a string.  As RFC2822 requires, the
    # special tokens . and @ will have no surrounding white space, all
    # other tokens will have a single space.
    def Address.join_tokens(tokens)
      joined = ''
      unless tokens.nil?
        sep = ''
        tokens.each { |token|
          unless token[0] == :whitespace
            if token[0] == :special && (token[1] == '@' || token[1] == '.')
              joined << token[1]
              sep = ''
            else
              joined << sep
              joined << token[1]
              sep = ' '
            end
          end
        }
      end
      joined
    end

    # Split a token list holding an addr-spec (local-part @ domain)
    # into the local part and the domain part.
    def Address.split_address(tokens)
      if tokens.nil?
	[[],[]]
      else
	at = tokens.rindex([:special, '@'])
	case at
	when nil
	  [tokens, []]
	when 0
	  [[], tokens[1..-1]]
	else
	  [tokens[0..at-1], tokens[at+1..-1]]
	end
      end
    end
  end
end
