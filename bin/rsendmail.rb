#!/usr/bin/env ruby
#--
#   Copyright (C) 2002 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#
require 'mail/parser'
require 'mail/address'
require 'mail/serialize'

def syslog(str)
  system('logger', '-p', 'mail.info', '-t', 'rsendmail', str.to_s)
end

extract_recipients = false
sender = nil
full_name = nil
single_dot_ends = true
end_of_options = false
recipients = []
while not ARGV.empty?
  arg = ARGV.shift
  if ! recipients.empty? || arg =~ /\A[^-]/ || end_of_options
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
    when '--'
      end_of_options = true
    else
      $stderr.puts("rsendmail: invalid option -- #{arg}")
      exit 1
    end
  end
end

# FIXME: parsing messages should be external to the Mail::Message
# class.  For example, we should differentiate here between -oi and
# not -oi.
message = Mail::Parser.new.parse($stdin)

def get_recipients(message, field_name, list)
  unless message.header[field_name].nil?
    Mail::Address.parse(message.header[field_name]).each do |address|
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

# FIXME: share with .rdeliver
def with_db(name)
  require 'gdbm'
  begin
    db = nil
    begin
      db = GDBM::open(File.join("/home/matt/.rfilter/var", name), 0600)
    rescue Errno::EWOULDBLOCK
      # FIXME: only wait so long, then defer
      sleep(2)
      retry
    end
    yield db
  ensure
    db.close unless db.nil?
  end
end

# FIXME: share with .rdeliver
def record_string_in_db(db, address)
  record = db[address]
  count = record.split(/:/)[1] unless record.nil?
  count ||= '0'
  db[address] = Time.now.strftime("%Y%m%d") + ':' + count.succ
end

with_db('sent-recipient') do |db|
  dup = {}
  recipients.each do |r|
    address = r.downcase
    record_string_in_db(db, address) unless dup.key?(address)
    dup[address] ||= 1
  end
end

with_db "sent-subjects" do |db|
  if subject = message.header['subject']
    subject = subject.strip.downcase
    record_string_in_db(db, subject)
  end
end

with_db "sent-msgid" do |db|
  if msgid = message.header['message-id']
    msgid = msgid.strip.downcase
    record_string_in_db(db, msgid)
  end
end


# FIXME: delete any bcc headers

# FIXME: should be able to generate a default From: header
#raise 'no from header' if message.header['from'].nil?

# FIXME: more error checking here

IO.popen('-', 'w') do |child|
  if child.nil?
    # FIXME: instead of 'address' need a way to output the address for
    # SMTP purposes.
    command = ['/usr/sbin/sendmail', '-oi']
    command.concat(['-F', full_name]) if full_name
    command.concat(['-f', sender]) if sender
    command.concat(recipients)
    #syslog("args ouggoing: " + command.inspect)
    exec(*command)
  else
    Mail::Serialize.new(child).serialize(message)
  end
end
