#!/usr/bin/env ruby
#--
#   Copyright (C) 2002 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

require 'tests/testbase'
require 'mail/keyed_mailbox'
require 'mail/message'
require 'ftools'

class TestMail__KeyedMailbox < TestBase
  def test_s_new
    assert_exception(ArgumentError) {
      Mail::KeyedMailbox.new
    }
    obj = Mail::KeyedMailbox.new(scratch_filename('test'))
    assert_instance_of(Mail::KeyedMailbox, obj)
    assert_respond_to(:save, obj)
    assert_respond_to(:delete, obj)
    assert_respond_to(:expire, obj)
  end

  def test_save
    dir = scratch_filename('queue')
    message = Mail::Message.new
    message.header['to'] = 'bob@example.net'
    message.header['from'] = 'sally@example.net'
    message.header['subject'] = 'rutabaga'
    message.body = 'message body'

    queue = Mail::KeyedMailbox.new(dir)
    key = queue.save(message)
    assert_match(/^[A-F\d][A-F\d-]+[A-F\d]$/, key)
  end

  def test_retrieve
    dir = scratch_filename('queue')
    message = Mail::Message.new
    message.header['to'] = 'bob@example.net'
    message.header['from'] = 'sally@example.net'
    message.header['subject'] = 'rutabaga'
    message.body = 'message body'

    queue = Mail::KeyedMailbox.new(dir)
    key = queue.save(message)
    filename = queue.retrieve(key)
    assert_equal(File.join(dir, 'new'), File.dirname(filename))
    assert(File::exists?(filename))

    filename2 = File.join(dir, 'cur', File::basename(filename) + ':2')
    File::move(filename, filename2)
    assert_equal(filename2, queue.retrieve(key))

    File::delete(filename2)
    assert_equal(nil, queue.retrieve(key))

    File::delete(File.join(dir, '.index', key))
    assert_equal(nil, queue.retrieve(key))
  end

  def test_delete
    dir = scratch_filename('queue')
    message = Mail::Message.new
    message.header['to'] = 'bob@example.net'
    message.header['from'] = 'sally@example.net'
    message.header['subject'] = 'rutabaga'
    message.body = 'message body'

    queue = Mail::KeyedMailbox.new(dir)
    key = queue.save(message)

    index = File.join(dir, '.index', key)
    file = queue.retrieve(key)
    assert(File::exists?(index))
    assert(File::exists?(file))
    queue.delete(key)
    assert_equal(false, File::exists?(index))
    assert_equal(false, File::exists?(file))

    assert_no_exception {
      queue.delete('ABDFABDF')
    }
  end

  def test_expire
    dir = scratch_filename('queue')
    message = Mail::Message.new
    message.header['to'] = 'bob@example.net'
    message.header['from'] = 'sally@example.net'
    message.header['subject'] = 'rutabaga'
    message.body = 'message body'

    queue = Mail::KeyedMailbox.new(dir)
    key = queue.save(message)
    assert_not_nil(queue.retrieve(key))
    queue.expire(1)
    assert_not_nil(queue.retrieve(key))
    queue.expire(0)
    assert_equal(nil, queue.retrieve(key))
  end
end
