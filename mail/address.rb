#!/usr/bin/env ruby
#
#   Copyright (c) 2001 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

module Mail
  class Address

    attr :local, true
    attr :domain

    ATEXT = '[\w=!#$%&\'*+-?^\`{|}~]+'

    def initialize
    end

    def display_name
      @display_name
    end

    def display_name=(str)
      @display_name = str
    end

    def comments=(array)
      @comments = array
    end

    def domain=(domain)
      @domain = if domain.nil? or domain == ''
		  nil
		else
		  domain
		end
    end

    def name
      @display_name || (@comments && @comments.last)
    end
    
    def address
      if @domain.nil?
	@local
      else
	@local + '@' + @domain
      end
    end

    def comments
      @comments
    end

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

    def Address.tokenize(str)
      puts ">tokenize #{str.inspect}" if $DEBUG
      words = []
      loop {
	case str
	when ""			# the end
	  break
	when /\A[\r\n\t ]+/m	# whitespace
	  puts "see whitespace #{$MATCH.inspect} #{$PREMATCH.inspect}" if $DEBUG
	  str = $POSTMATCH
	when /\A\(/m # comment
	  puts "see comment #{str.inspect}" if $DEBUG
	  depth = 0
	  comment = ''
	  catch(:done) {
	    while str =~ /\A(\(([^\(\)\\]|\\.)*)/m
	      str = $POSTMATCH
	      comment += $1
	      depth += 1
	      puts "depth #{depth}, comment now #{comment.inspect}, str now #{str.inspect}" if $DEBUG
	      while str =~ /\A(([^\(\)\\]|\\.)*\))/m
		str = $POSTMATCH
		comment += $1
		depth -= 1
		puts "depth #{depth}, comment now #{comment.inspect}, str now #{str.inspect}" if $DEBUG
		throw :done if depth == 0
		if str =~ /\A(([^\(\)\\]|\\.)+)/
		  str = $POSTMATCH
		  comment += $1
		  puts "depth #{depth}, comment now #{comment.inspect}, str now #{str.inspect}" if $DEBUG
		end
	      end
	    end
	  }
	  words.push([:comment,
		       comment.
		       gsub(/[\r\n\t ]+/m, ' ').
		       sub(/\A\((.*)\)$/m, '\1').
		       gsub(/\\(.)/, '\1')])
	when /\A[\w!$%&'*+\/=?^_`{\}|~#-]+/m
	  puts "see atom" if $DEBUG
	  str = $POSTMATCH
	  words.push([:atom, $MATCH])
	when /\A""/
	  puts "see empty double quote" if $DEBUG
	  str = $POSTMATCH
	when /\A"(.*?([^\\]|\\\\))"/m
	  puts "see quote" if $DEBUG
	  str = $POSTMATCH
	  words.push([:qtext, $1.gsub(/\\(.)/, '\1')]) unless $1.nil?
	when /\A(\[.*?([^\\]|\\\\)\])/m
	  puts "see domain literal #{$1.inspect}" if $DEBUG
	  str = $POSTMATCH
	  words.push([:domain_literal, $1.gsub(/\\(.)/, '\1')])
	when /\A[<>@,:;\.]/m
	  puts "see literal" if $DEBUG
	  words.push([:special, $MATCH])
	  str = $POSTMATCH
	when /\A\W+/m		# not atom
	  puts "see weirdness" if $DEBUG
	  str = $POSTMATCH
	  words.push([:not_atom, $MATCH])
	end
	puts "last token #{words[-1].inspect}" if $DEBUG
	puts "str #{str.inspect}" if $DEBUG
      }
      puts "<tokenize #{words.inspect}" if $DEBUG
      words
    end

    # Join a series of tokens into a string.  The special tokens . and @
    # will have no surrounding white space, all other tokens will
    # have a single space.
    def Address.join_tokens(tokens)
      joined = ''
      sep = ''
      unless tokens.nil?
	tokens.each_with_index { |token, i|
	  if token[0] == :special && (token[1] == '@' || token[1] == '.')
	    joined += token[1]
	    sep = ''
	  else
	    joined += sep + token[1]
	    sep = ' '
	  end
	}
      end
      joined
    end

    # Split a series of tokens holding an addr-spec (local-part @ domain)
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

    def Address.parse(str)
      require "English"

      puts "\nparse #{str.inspect}" if $DEBUG
      
      token_list = tokenize(str)
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
	    display_name = join_tokens(tokens[0, angle_index])
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
  end
end

