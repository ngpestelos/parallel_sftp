# frozen_string_literal: true

module ParallelSftp
  # Parses lftp output to extract progress information
  class ProgressParser
    # Regex patterns for parsing lftp pget output
    PROGRESS_PATTERN = /(\d+(?:\.\d+)?)\s*([KMGT]?B?)\/s/.freeze
    BYTES_PATTERN = /(\d+(?:\.\d+)?)\s*([KMGT]?)B?\s+(?:of\s+)?(\d+(?:\.\d+)?)\s*([KMGT]?)B?/.freeze
    PERCENT_PATTERN = /(\d+)%/.freeze
    ETA_PATTERN = /eta:?\s*(\d+[hms](?:\d+[ms])?|\d+:\d+(?::\d+)?)/.freeze

    attr_reader :bytes_transferred, :total_bytes, :speed, :percent, :eta

    def initialize
      @bytes_transferred = 0
      @total_bytes = 0
      @speed = 0
      @percent = 0
      @eta = nil
    end

    # Parse a line of lftp output and update progress info
    # Returns true if progress was updated, false otherwise
    def parse(line)
      return false if line.nil? || line.strip.empty?

      updated = false

      # Extract percentage
      if (match = line.match(PERCENT_PATTERN))
        @percent = match[1].to_i
        updated = true
      end

      # Extract speed
      if (match = line.match(PROGRESS_PATTERN))
        @speed = parse_size(match[1], match[2])
        updated = true
      end

      # Extract bytes transferred and total
      if (match = line.match(BYTES_PATTERN))
        @bytes_transferred = parse_size(match[1], match[2])
        @total_bytes = parse_size(match[3], match[4])
        updated = true
      end

      # Extract ETA
      if (match = line.match(ETA_PATTERN))
        @eta = match[1]
        updated = true
      end

      updated
    end

    # Return progress info as a hash
    def to_h
      {
        bytes_transferred: bytes_transferred,
        total_bytes: total_bytes,
        speed: speed,
        percent: percent,
        eta: eta
      }
    end

    private

    def parse_size(value, unit)
      base = value.to_f
      multiplier = case unit.upcase.gsub("B", "")
                   when "K" then 1024
                   when "M" then 1024**2
                   when "G" then 1024**3
                   when "T" then 1024**4
                   else 1
                   end
      (base * multiplier).to_i
    end
  end
end
