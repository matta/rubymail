#--
#   Copyright (C) 2002, 2003 Matt Armstrong.  All rights reserved.
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
# Implements the RMail::Serialize class.

module RMail

  # The RMail::Serialize class writes an RMail::Message object into an
  # IO object or string.  The result is a standard mail message in
  # text form.
  #
  # To do this, you pass the RMail::Message object to the
  # RMail::Serialize object.  RMail::Serialize can write into any
  # object supporting the << method.
  #
  # As a convenience, RMail::Serialize.write is a class method you can
  # use directly:
  #
  #  # Write to a file
  #  File.open('my-message', 'w') { |f|
  #    RMail::Serialize.write(f, message)
  #  }
  #
  # # Write to a new string
  # string = RMail::Serialize.write('', message)
  class Serialize

    @@boundary_count = 0

    # Initialize this Serialize object with an output stream.  If
    # escape_from is not nil, lines with a leading From are escaped.
    def initialize(output, escape_from = nil)
      @output = output
      @escape_from = escape_from
    end

    # Serialize a given message into this object's output object.
    def serialize(message)
      calculate_boundaries(message) if message.multipart?
      serialize_low(message)
    end

    # Serialize a message into a given output object.  The output
    # object must support the << method in the same way that an IO or
    # String object does.
    def Serialize.write(output, message)
      Serialize.new(output).serialize(message)
    end

    private

    def serialize_low(message, depth = 0)
      if message.multipart?
        delimiters, delimiters_boundary = message.get_delimiters
        unless delimiters
          boundary = "\n--" + message.header.param('Content-Type', 'boundary')
          delimiters = Array.new(message.body.length + 1, boundary + "\n")
          delimiters[-1] = boundary + "--\n"
        end

        @output << message.header.to_s

        if message.body.length > 0 or message.preamble or
            delimiters.last.length > 0
          @output << "\n"
        end

        if message.preamble
          @output << message.preamble
        end

        delimiter = 0
        message.each_part { |part|
          @output << delimiters[delimiter]
          delimiter = delimiter.succ
          serialize_low(part, depth + 1)
        }

        @output << delimiters[delimiter]

        if message.epilogue
          @output << message.epilogue
        end

      else
        @output << message.header.to_s
        unless message.body.nil?
          @output << "\n"
          @output << message.body
          if depth == 0 and message.body.length > 0 and
              message.body[-1] != ?\n
            @output << "\n"
          end
        end
      end
      @output
    end

    # Walk the multipart tree and make sure the boundaries generated
    # will actually work.
    def calculate_boundaries(message)
      calculate_boundaries_low(message, [])
      unless message.header['MIME-Version']
        message.header['MIME-Version'] = "1.0"
      end
    end

    def calculate_boundaries_low(part, boundaries)
      # First, come up with a candidate boundary for this part and
      # save it in our list of boundaries.
      boundary = make_and_set_unique_boundary(part, boundaries)

      # Now walk through each part and make sure the boundaries are
      # suitable.  We dup the boundaries array before recursing since
      # sibling multipart can re-use boundary strings (though it isn't
      # a good idea).
      boundaries.push(boundary)
      part.each_part { |p|
        calculate_boundaries_low(p, boundaries) if p.multipart?
      }
      boundaries.pop
    end

    # Generate a random boundary
    def generate_boundary
      @@boundary_count += 1
      t = Time.now
      sprintf("=-%d-%d-%d-%d-%d-=",
              t.tv_sec.to_s,
              t.tv_usec.to_s,
              Process.pid.to_s,
              rand(10000),
              @@boundary_count)
    end

    # Returns a boundary that will probably work out.  Extracts any
    # existing boundary from the header, but will generate a default
    # one if the header doesn't have one set yet.
    def make_and_set_unique_boundary(part, boundaries)
      candidate = part.header.param('content-type', 'boundary')
      unique = make_unique_boundary(candidate || generate_boundary, boundaries)
      if candidate.nil? or candidate != unique
        part.header.set_boundary(unique)
      end
      unique
    end

    # Make the passed boundary unique among the passed boundaries and
    # return it.
    def make_unique_boundary(boundary, boundaries)
      continue = true
      while continue
        continue = false
        boundaries.each do |existing|
          if boundary == existing[0, boundary.length]
            continue = true
            break
          end
        end
        break unless continue
        boundary = generate_boundary
      end
      boundary
    end

  end
end
