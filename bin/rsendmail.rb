#!/usr/bin/env ruby
=begin
   Copyright (C) 2002 Matt Armstrong.  All rights reserved.

   Permission is granted for use, copying, modification,
   distribution, and distribution of modified versions of this work
   as long as the above copyright notice is included.
=end

require 'mail/message'
require 'mail/address'
require 'hmac-sha1'

# Add some useful methods to the String class
class String
  def unhexlify
    [self].pack("H*")
  end
  def hexlify
    unpack("H*")[0]
  end
  def base64
    [self].pack("m*")
  end
  def uuencode
    [self].pack("u*")
  end
end

#$crypt_key = "640111e743bf168149ced3068adc0700dff2003d"
$crypt_key = "73b41d0a9dc4857a89689fb492a2bbdf891e4068"

extract_recipients = false
sender = nil
full_name = nil
single_dot_ends = true
recipients = []
while not ARGV.empty?
  arg = ARGV.shift
  if ! recipients.empty? || arg =~ /\A[^-]/
    recipients.push(arg)
  else
    case arg
    when '-t'
      extract_recipients = true
    when '-f'
      sender = ARGV.shift
    when '-F'
      full_name = ARGV.shift
    when '-oi'
      single_dot_ends = false
    else
      $stderr.puts("rsendmail: invalid option -- ${arg}")
      exit 1
    end
  end
end

specials = Hash.new

File.open(File::expand_path("~/.keyword")) { |f|
  f.each { |l|
    case l
    when /^\s*\#/
      next
    when /^\s*$/
      next
    else
      a, k = l.split(' ')
      specials[a.downcase] = "keyword=#{k.strip.downcase}"
    end
  }
}

File.open(File::expand_path("~/.whitelist")) { |f|
  f.each { |l|
    case l
    when /^\s*\#/
      next
    when /^\s*$/
      next
    else
      specials[l.strip.downcase] = "bare"
    end
  }
}

# FIXME: parsing messages should be external to the Mail::Message
# class.  For example, we should differentiate here between -oi and
# not -oi.
message = Mail::Message.new($stdin)

def get_recipients(message, field_name, list)
  unless message.header.get(field_name).nil?
    Mail::Address.parse(message.header.get(field_name)).each do |address|
      # FIXME: need an "smtpaddress" method
      list.push(address.address)
    end
  end
end

if extract_recipients
  get_recipients(message, 'to',  recipients)
  get_recipients(message, 'cc',  recipients)
  get_recipients(message, 'bcc', recipients)
end

# FIXME: put this into some kind of library
# FIXME: simplify verp recipients?
begin
  require 'dbm'
  db = nil
  begin
    db = DBM::open(File.expand_path("~/.sent-mail-to"), 0600)
  rescue Errno::EWOULDBLOCK
    # FIXME: back of exponentially and only wait so long
    sleep(1)
    retry
  end
  recipients.each do |r|
    record = db[r]
    count = record.split(/:/)[1] unless record.nil?
    count ||= '0'
    db[r] = Time.now.strftime("%Y%m%d") + ':' + count.succ
  end
ensure
  db.close unless db.nil?
end

# FIXME: delete any bcc headers

# FIXME: should be able to generate a default From: header
raise 'no from header' if message.header['from'].nil?

# FIXME: should tag Resent-From: if present instead of From:
# FIXME: what if from address has no domain?  Hmm...
# FIXME: generate Date and Message-ID headers if not present
# FIXME: deal with multiple people in the From: header.
# FIXME: tag any Sender: header if appropriate

# FIXME: more error checking here
from = Mail::Address.parse(message.header['from'])[0]
raise if from.nil?

def hash_match(address, hash)
  address = Mail::Address.parse(address.downcase)[0]
  a = address.address
  if hash.key?(a)
    return hash[a]
  end
  return nill unless address.domain
  d = address.domain.downcase
  if hash.key?("@#{d}")
    return hash["@#{d}"]
  end
  parts = d.split(/\./)
  while not parts.empty?
    d = '.' + parts.join('.')
    if hash.key?(d)
      return hash[d]
    end
    parts.shift
  end
  return nil
end

types = Hash.new(nil)
raise "no recipients" if recipients.empty?
recipients.each do |r|
  type = hash_match(r, specials)
  type ||= 'dated'
  types[type] ||= []
  types[type].push(r)
end

def tag_dated(local)
  tohash = (Time.now + (60*60*24*5)).strftime("%Y%m%d%H%S")
  cookie = HMAC::SHA1.digest($crypt_key.unhexlify, tohash)[0...3].hexlify
  "#{local}+dated+#{tohash}.#{cookie}"
end

def tag_keyword(local, keyword)
  keyword = keyword.downcase.gsub(/[^a-zA-Z0-9!#$\%&'*+-\/=?^_`{|}~-]/, '?')
  cookie = HMAC::SHA1.digest($crypt_key.unhexlify, keyword)[0...3].hexlify
  local + "+#{keyword}.#{cookie}"
end

# FIXME: delete any return-path: header

types.each_pair do |tag, recipients|
  puts "type #{tag.inspect} recipients #{recipients.inspect}" if $DEBUG

  # FIXME: need Mail::Address.dup
  local_from = Mail::Address.parse(from.format)[0]

  # FIXME: really need a simple way to replace the From: header
  newhdr = message.header.find_all do |name, line|
    name != 'from'
  end
  message.header.clear
  newhdr.each do |name, line|
    message.header.add(nil, line)
  end
  
  case tag
  when 'dated'
    local_from.local = tag_dated(local_from.local)
  when 'bare'
    # do nothing
  when /^keyword=(\S+)/
    local_from.local = tag_keyword(local_from.local, $1)
  else
    raise "bogus tag type #{tag}"
  end

  # FIXME: really need a []= method on Mail::Header
  # FIXME: really needs to understand Mail::Address args, or
  # maybe just call to_s
  # FIXME: really need a way to replace a header
  # FIXME: Mail::Address needs to make to_s an alias of format
  # FIXME: Mail::Header.add seems to downcase the field name, fix that
  message.header.delete('From').add('From', local_from.format)
  
  puts "sending as #{local_from.format} to #{recipients.inspect}" if $DEBUG

  IO.popen('-', 'w') do |child|
    if child.nil?
      # FIXME: instead of 'address' need a way to output the address
      # for SMTP purposes.
      exec('/usr/sbin/sendmail', '-oi', '-f', local_from.address, *recipients)
    else
      message.each do |line|
	child.puts line
      end
    end
  end
end

