#--
#   Copyright (C) 2002-2005 Matt Armstrong.  All rights reserved.
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
# Implements the RMail::Parser, RMail::StreamParser and
# RMail::StreamHandler classes.

require 'rmail/message'
require 'rmail/parser/multipart'
require 'rmail/parser/normalizeeolreader'
require 'rmail/parser/accumulatereader'

module RMail

  # = Overview
  #
  # An RMail::StreamHandler documents the set of methods a
  # RMail::StreamParser handler must implement.  See
  # RMail::StreamParser.parse.  This is a low level interface to
  # the RubyMail message parser.
  #
  # = Order of Method Calls (Grammar)
  #
  # Calls to the methods of this class follow a specific grammar,
  # described informally below.  The words in all caps are productions
  # in the grammar, while the lower case words are method calls to
  # this object.
  #
  # MESSAGE::         [ #mbox_from ] *( #header_field )
  #                   ( BODY / MULTIPART_BODY )
  #                   #raw_entity
  #
  # BODY::            *body_begin *( #body_chunk ) #body_end
  #
  # MULTIPART_BODY::  #multipart_body_begin
  #                   *( #preamble_chunk )
  #                   *( #part_begin MESSAGE #part_end)
  #                   *( #epilogue_chunk )
  #                   #multipart_body_end
  #
  # = Order of Method Calls (English)
  #
  # If the grammar above is not clear, here is a description in English.
  #
  # The parser begins calling #header_field, possibly calling
  # #mbox_from for the first line.  Then it determines if the message
  # was a MIME multipart message.
  #
  # If the message is a not a MIME multipart, the parser calls
  # #body_begin once, then #body_chunk any number of times, then
  # #body_end.
  #
  # If the message header is a MIME multipart message, then
  # #multipart_body_begin is called, followed by any number of calls
  # to #preamble_chunk.  Then for each part parsed, #part_begin is
  # called, followed by a recursive set of calls described by the
  # "MESSAGE" production above, and then #part_end.  After all parts
  # are parsed, any number of calls to #epilogue_chunk are followed by
  # a single call to #multipart_body_end.
  #
  # The #raw_entity method is always called after #body_end or
  # #multipart_body_end with the raw data for the entire
  # entity.  This can be saved away for later use (e.g. re-creation of
  # the original message, or cryptographic signature verification).
  #
  # The recursive nature of MIME multipart messages is represented by
  # the recursive invocation of the "MESSAGE" production in the
  # grammar above.
  class StreamHandler

    # This method is called for Unix MBOX "From " lines in the message
    # header, it calls this method with the text.
    def mbox_from(line)
    end

    # This method is called when a header field is parsed.  The
    # +field+ is the full text of the field, the +name+ is the name of
    # the field and the +value+ is the field's value with leading and
    # trailing whitespace removed.  Note that both +field+ and +value+
    # may be multi-line strings.
    def header_field(field, name, value)
    end

    # This method is called before a non-multipart message body is
    # about to be parsed.
    def body_begin
    end

    # This method is called with a string chunk of data from a
    # non-multipart message body.  The string does not necessarily
    # begin or end on any particular boundary, but is guaranteed to
    # not extend past the end of the current MIME entity.
    def body_chunk(chunk)
    end

    # This method is called after all of the non-multipart message
    # body has been parsed.
    def body_end
    end

    # This method is called before a multipart message body is about
    # to be parsed.
    def multipart_body_begin
    end

    # This method is called with a chunk of data from a multipart
    # message body's preamble.  The preamble is any text that appears
    # before the first part of the multipart message body.
    def preamble_chunk(chunk)
    end

    # This method is called when a part of a multipart body begins.
    def part_begin
    end

    # This method is called when a part of a multipart body ends.
    def part_end
    end

    # This method is called with a chunk of data from a multipart
    # message body's epilogue.  The epilogue is any text that appears
    # after the last part of the multipart message body.
    def epilogue_chunk(chunk)
    end

    # This method is called after a multipart message body has been
    # completely parsed.
    #
    # The +delimiters+ is an Array of strings, one for each boundary
    # string found in the multipart body.  The +boundary+ is the
    # boundary string used to delimit each part in the multipart body.
    # You can normally ignore both +delimiters+ and +boundary+ if you
    # are concerned only about message content.
    def multipart_body_end(delimiters, boundary)
    end

    # This method is called after a call to #body_end or
    # #multipart_body_end.  The supplied +data+ is the raw entity data
    # for the entire part (+whole+) as well as the raw data for just
    # the +header+ and +body+ portions.  These objects are
    # RMail::Substring objects.
    def raw_entity(header, body, whole)
    end
  end

  # The RMail::StreamParser is a low level message parsing API.
  # For input, accepts either an +IO+object, a +String+ or an object
  # that implements +#to_str+.  It then calls various methods on a
  # +handler+ object that conforms to the StreamHandler API as the
  # structure of the message becomes apparent.
  #
  # The advantage of the parser operating in chunks of data instead of
  # lines is efficiency.  E.g. an 80k document base64 encoded will
  # amount to roughly 1500 lines of text but only eight 16k chunks of
  # data.  This results in a measurable performance gain.
  #
  # This class is useful when you are interested in serially examining
  # all message content but are not interested in a full object
  # representation of the object.  See StreamParser.parse.
  #
  # If you are interested in the entire structure of the message, see
  # RMail::Parser.
  class StreamParser

    class << self

      # Parse a message from an input source.  This method returns
      # nothing.  Instead, the supplied +handler+ is expected to
      # implement the same methods as RMail::StreamHandler.  The
      # message structure can be inferred from the methods called on
      # the +handler+.  The +input+ can be any Ruby IO source or a
      # String.
      #
      # This is a low level parsing API.  For a message parser that
      # returns an RMail::Message object, see the RMail::Parser class.
      # RMail::Parser is implemented using RMail::StreamParser.
      def parse(input, handler)
        RMail::StreamParser.new(input, handler).parse
      end
    end

    def initialize(input, handler) # :nodoc:
      @input = input
      @handler = handler
      @chunk_size = nil
    end

    def parse                   # :nodoc:

      #
      # IMPROVE: the fact that I have to pass a pos of 0 here suggests
      # that PushbackReader should not support #pos, but instead a
      # derived class.  Then, NormalizeEOLReader wouldn't be tracking
      # #pos, but other readers could as needed.
      #
      input = RMail::Parser::NormalizeEOLReader.new(@input, 0)

      # Create an AccumulateReader to accumulate all input data for
      # this parse.
      #
      # TODO: figure out a nice way to make this optional, make it
      # spool to a file, etc.
      accumulator = RMail::Parser::AccumulateReader.new(input)

      accumulator.chunk_size = @chunk_size if @chunk_size

      parse_low(accumulator, accumulator, 0)
      return nil
    end

    # Change the chunk size used to read the message.  This is useful
    # mostly for testing, so we don't document it.
    attr_accessor :chunk_size   # :nodoc:

    private

    def parse_low(accumulator, input, depth)

      start_pos = input.pos

      multipart_boundary = parse_header(input, depth)

      body_pos = input.pos

      if multipart_boundary
        parse_multipart_body(accumulator, input, depth, multipart_boundary)
      else
        parse_singlepart_body(input, depth)
      end

      end_pos = input.pos

      header_substring = accumulator.substring(start_pos,
                                               body_pos - start_pos)
      body_substring = accumulator.substring(body_pos,
                                             end_pos - body_pos)
      whole_substring = accumulator.substring(start_pos,
                                              end_pos - start_pos)

      @handler.raw_entity(header_substring,
                          body_substring,
                          whole_substring)
    end

    def parse_header(input, depth)
      data = nil
      header = nil
      pushback = nil
      boundary = nil
      while chunk = input.read
        data ||= ''
        data << chunk
        if data[0] == ?\n
          # A leading newline in the message is seen when parsing the
          # parts of a multipart message.  It means there are no
          # headers.  The body part starts directly after this
          # newline.
          rest = data[1..-1]
        else
          header, rest = data.split(/\n\n/, 2)
        end
        break if rest
      end
      input.pushback(rest) if rest
      if header
        mime = false
        fields = header.split(/\n(?!\s)/)
        if fields.first =~ /^From /
          @handler.mbox_from(fields.first)
          fields.shift
        end
        fields.each { |field|
          if field =~ /^From /
            @handler.mbox_from(field)
          else
            name, value = RMail::Header::Field.parse(field)
            case name.downcase
            when 'mime-version'
              if value =~ /\b1\.0\b/
                mime = true
              end
            when 'content-type'
              # FIXME: would be nice to have a procedural equivalent
              # to RMail::Header#param.
              header = RMail::Header.new
              header['content-type'] = value
              boundary = header.param('content-type', 'boundary')
            end
            @handler.header_field(field, name, value)
          end
        }
        unless mime or depth > 0
          boundary = nil
        end
      end
      return boundary
    end

    def parse_multipart_body(accumulator, input, depth, boundary)
      input = RMail::Parser::MultipartReader.new(input, input.pos, boundary)
      input.chunk_size = @chunk_size if @chunk_size

      @handler.multipart_body_begin

      # Reach each part, adding it to this entity as appropriate.
      delimiters = []
      while input.next_part
        if input.preamble?
          while chunk = input.read
            @handler.preamble_chunk(chunk)
          end
        elsif input.epilogue?
          while chunk = input.read
            @handler.epilogue_chunk(chunk)
          end
        else
          @handler.part_begin
          parse_low(accumulator, input, depth + 1)
          @handler.part_end
        end
        delimiters << (input.delimiter || "") unless input.epilogue?
      end
      @handler.multipart_body_end(delimiters, boundary)
    end

    def parse_singlepart_body(input, depth)
      @handler.body_begin
      while chunk = input.read
        @handler.body_chunk(chunk)
      end
      @handler.body_end
    end

  end

  # The RMail::Parser class creates RMail::Message objects from Ruby
  # IO objects or strings.
  #
  # To parse from a string:
  #   message = RMail::Parser.read(the_string)
  #
  # To parse from an IO object:
  #   message = File.open('my-message') { |f|
  #     RMail::Parser.read(f)
  #   }
  #
  # You can also parse from STDIN, etc.
  #   message = RMail::Parser.read(STDIN)
  #
  # In all cases, the parser consumes all input.
  class Parser

    # Creates a new parser.  Messages of +message_class+ will be
    # created by the parser.  By default, the parser will create
    # RMail::Message objects.
    def initialize()
      @chunk_size = nil
    end

    # Parse a message from the IO object +io+ and return a new
    # message.  The +io+ object can also be a +String+ or an object
    # that implements +#to_str+.
    def parse(input)
      handler = RMail::Parser::Handler.new
      parser = RMail::StreamParser.new(input, handler)
      parser.chunk_size = @chunk_size if @chunk_size
      parser.parse
      return handler.message
    end

    # Change the chunk size used to read the message.  This is useful
    # mostly for testing.
    attr_accessor :chunk_size

    # Parse a message from the IO object +io+ and return a new
    # message.  The +io+ object can also be a string.  This is just
    # shorthand for:
    #
    #   RMail::Parser.new.parse(io)
    def Parser.read(input)
      Parser.new.parse(input)
    end

    # A stream handler for parsing messages.
    class Handler               # :nodoc:
      def initialize
        @parts = [ RMail::Message.new ]
        @preambles = []
        @epilogues = []
        @save_body = []
      end
      def mbox_from(field)
        @parts.last.header.mbox_from = field
      end
      def header_field(field, name, value)
        @parts.last.header.add_raw(field)
      end
      def body_begin
        # This call will be paired with a call to #raw_entity, where
        # we will pop this value off the stack.
        #
        # Push a new save_body flag onto the stack and set it to
        # false.  It will be set to true in #body_chunk() if there is
        # actually any body data in the message.
        @save_body.push(false)
      end
      def body_chunk(chunk)
        # ignore the chunk, but set @save_body.last to true so
        # #raw_entity will save the body.
        @save_body[-1] = true
      end
      def body_end
        # ignore -- rely on #raw_entity to save the body if
        # appropriate.
      end
      def multipart_body_begin
        # This call will be paired with a call to #raw_entity, where
        # we will pop this value off the stack.
        @save_body.push(false)

        @preambles.push(nil)
        @epilogues.push(nil)
      end
      def preamble_chunk(chunk)
        if @preambles.last
          @preambles.last << chunk
        else
          @preambles[-1] = chunk
        end
      end
      def epilogue_chunk(chunk)
        if @epilogues.last
          @epilogues.last << chunk
        else
          @epilogues[-1] = chunk
        end
      end
      def multipart_body_end(delimiters, boundary)
        @parts.last.preamble = @preambles.pop
        @parts.last.epilogue = @epilogues.pop
        if @parts.last.body.nil?
          @parts.last.body = []
        end
        @parts.last.set_delimiters(delimiters, boundary)
      end
      def part_begin
        @parts << RMail::Message.new
      end
      def part_end
        part = @parts.pop
        @parts.last.add_part(part)
      end
      def message
        @parts.first
      end
      def raw_entity(header,
                     body,
                     whole)
        @parts.last.raw_entity = whole
        save_body = @save_body.pop
        if save_body
          @parts.last.body = body
        end
      end
    end

  end
end
