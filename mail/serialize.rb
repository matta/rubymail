#!/usr/bin/env ruby
#--
#   Copyright (C) 2002 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

module Mail

  # Serialize a Mail::Message object into an output stream supporting
  # the << method.
  class Serialize

    @@boundary_count = 0

    class Error
    end

    # Initialize this Serialize object with an output stream.  If
    # escape_from is not nil, lines with a leading From are escaped.
    def initialize(output, escape_from = nil)
      @output = output
      @escape_from = escape_from
    end

    def serialize(message)
      serialize_low(message)
    end

    private

    def serialize_low(message, depth = 0)
      if message.multipart?
        if depth == 0
          calculate_boundaries(message)
        end
        @output << message.header.to_s + "\n"
        boundary = '--' + message.header.param('Content-Type', 'boundary')
        if message.preamble
          @output << message.preamble
          @output << "\n"
        end
        message.each_part { |part|
          @output << boundary
          @output << "\n"
          serialize_low(part, depth + 1)
        }
        @output << boundary
        @output << "--\n"
        if message.epilogue
          @output << message.epilogue
          @output << "\n" if depth > 0 || message.epilogue[-1] != ?\n
        end
      else
        @output << message.header.to_s + "\n"
        unless message.body.nil?
          @output << message.body
          @output << "\n" if depth > 0 || message.body[-1] != ?\n
        end
      end
      @output
    end

    # Walk the multipart tree and make sure the boundaries generated
    # will actually work.
    def calculate_boundaries(message)

      boundaries = []
      calculate_boundaries_low(message, boundaries)

      boundaries.each do |boundary, part|
        if boundary != part.header.param('content-type', 'boundary')
          part.header.set_boundary(boundary)
        end
      end

      unless message.header['MIME-Version']
        message.header['MIME-Version'] = "1.0"
      end
    end

    def calculate_boundaries_low(part, boundaries)
      raise Error unless part.multipart?

      # First, come up with a candidate boundary for this part and
      # save it in our list of boundaries.
      boundary = cantidate_boundary(part, boundaries)
      boundaries << [ boundary, part ]

      # Now walk through each part and make sure the boundaries are
      # suitable.
      part.each_part { |p|
        calculate_boundaries_low(p, boundaries) if p.multipart?
      }
    end

    # Generate a random boundary
    def generate_boundary
      @@boundary_count += 1
      '=-' + [Time.now.to_i.to_s,
        Process.pid.to_s,
        rand(10000),
        @@boundary_count].join('-')
    end

    # Returns a boundary that will probably work out.  Extracts any
    # existing boundary from the header, but will generate a default
    # one if the header doesn't have one set yet.
    def cantidate_boundary(part, boundaries)
      candidate = part.header.param('content-type', 'boundary',
                                    generate_boundary)
      make_boundary_unique(candidate, boundaries)
    end

    # Make the passed boundary unique among the passed boundaries and
    # return it.
    def make_boundary_unique(boundary, boundaries)
      continue = true
      while continue
        continue = false
        boundaries.each do |existing, part|
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
