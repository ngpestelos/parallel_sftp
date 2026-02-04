# frozen_string_literal: true

module ParallelSftp
  # Calculates download speed and time estimates using a moving window of samples
  class TimeEstimator
    # Represents a single progress sample
    Sample = Struct.new(:bytes, :time, keyword_init: true)

    attr_reader :window_size

    # Initialize a new TimeEstimator
    #
    # @param window_size [Integer] Number of samples to keep for speed calculation (default: 10)
    def initialize(window_size: 10)
      @samples = []
      @window_size = window_size
      @start_time = nil
      @start_bytes = nil
    end

    # Record a progress sample
    #
    # @param bytes_downloaded [Integer] Total bytes downloaded so far
    # @param timestamp [Time] Time of the sample (default: Time.now)
    def record(bytes_downloaded, timestamp = Time.now)
      @start_time ||= timestamp
      @start_bytes ||= bytes_downloaded

      @samples << Sample.new(bytes: bytes_downloaded, time: timestamp)
      @samples.shift if @samples.size > @window_size
    end

    # Calculate current download speed based on recent samples
    #
    # @return [Integer, nil] Speed in bytes per second, or nil if insufficient data
    def speed_bytes_per_second
      return nil if @samples.size < 2

      first = @samples.first
      last = @samples.last

      bytes_delta = last.bytes - first.bytes
      time_delta = last.time - first.time

      return nil if time_delta <= 0
      (bytes_delta / time_delta).round
    end

    # Calculate estimated time remaining
    #
    # @param total_bytes [Integer] Total file size in bytes
    # @param current_bytes [Integer] Current bytes downloaded
    # @return [Integer, nil] Estimated seconds remaining, or nil if cannot calculate
    def eta_seconds(total_bytes, current_bytes)
      speed = speed_bytes_per_second
      return nil if speed.nil? || speed <= 0

      remaining = total_bytes - current_bytes
      return 0 if remaining <= 0

      (remaining.to_f / speed).round
    end

    # Calculate estimated time remaining as a formatted string
    #
    # @param total_bytes [Integer] Total file size in bytes
    # @param current_bytes [Integer] Current bytes downloaded
    # @return [String, nil] Formatted duration (e.g., "1h25m", "5m30s"), or nil
    def eta_formatted(total_bytes, current_bytes)
      seconds = eta_seconds(total_bytes, current_bytes)
      return nil if seconds.nil?

      format_duration(seconds)
    end

    # Elapsed time since first sample
    #
    # @return [Integer] Elapsed seconds
    def elapsed_seconds
      return 0 if @start_time.nil?
      (Time.now - @start_time).round
    end

    # Average speed since start of download
    #
    # @return [Integer, nil] Average speed in bytes per second, or nil
    def average_speed
      return nil if @start_time.nil? || @samples.empty?

      elapsed = Time.now - @start_time
      return nil if elapsed <= 0

      bytes = @samples.last.bytes - @start_bytes
      (bytes / elapsed).round
    end

    # Clear all recorded samples and reset state
    def reset!
      @samples = []
      @start_time = nil
      @start_bytes = nil
    end

    private

    def format_duration(seconds)
      return "0s" if seconds <= 0

      hours = seconds / 3600
      minutes = (seconds % 3600) / 60
      secs = seconds % 60

      if hours > 0
        "#{hours}h#{minutes}m"
      elsif minutes > 0
        "#{minutes}m#{secs}s"
      else
        "#{secs}s"
      end
    end
  end
end
