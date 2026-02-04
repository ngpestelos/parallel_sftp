# frozen_string_literal: true

module ParallelSftp
  # Parses lftp's .lftp-pget-status file to extract per-segment progress
  #
  # The status file format is:
  #   size=20955686931
  #   0.pos=57442304
  #   0.limit=2619460869
  #   1.pos=2670611717
  #   1.limit=5238921735
  #   ...
  #
  # Where:
  #   - size: Total file size in bytes
  #   - N.pos: Current position (bytes downloaded) for segment N
  #   - N.limit: End position (byte limit) for segment N
  class SegmentProgressParser
    # Represents a single download segment
    Segment = Struct.new(:index, :pos, :limit, :start, keyword_init: true) do
      def downloaded
        pos - start
      end

      def segment_size
        limit - start
      end

      def percent
        return 0.0 if segment_size.zero?
        ((downloaded.to_f / segment_size) * 100).round(1)
      end
    end

    attr_reader :total_size, :segments

    def initialize
      @total_size = nil
      @segments = []
    end

    # Parse a status file from disk
    #
    # @param status_file_path [String] Path to the .lftp-pget-status file
    # @return [Boolean] true if file was parsed successfully, false otherwise
    def parse(status_file_path)
      return false unless File.exist?(status_file_path)

      content = File.read(status_file_path)
      parse_content(content)
    end

    # Parse status file content directly
    #
    # @param content [String] Content of the status file
    # @return [Boolean] true if content was parsed successfully
    def parse_content(content)
      @segments = []
      @total_size = nil
      segment_data = {}

      lines = content.strip.split("\n")

      lines.each do |line|
        case line
        when /^size=(-?\d+)/
          @total_size = ::Regexp.last_match(1).to_i
        when /^(\d+)\.pos=(\d+)/
          idx = ::Regexp.last_match(1).to_i
          pos = ::Regexp.last_match(2).to_i
          segment_data[idx] ||= {}
          segment_data[idx][:pos] = pos
        when /^(\d+)\.limit=(\d+)/
          idx = ::Regexp.last_match(1).to_i
          limit = ::Regexp.last_match(2).to_i
          segment_data[idx] ||= {}
          segment_data[idx][:limit] = limit
        end
      end

      build_segments(segment_data)
      true
    end

    # Convert to hash representation
    #
    # @return [Hash] Hash with total_size, segments array, total_downloaded, and overall_percent
    def to_h
      {
        total_size: total_size,
        segments: segments.map { |s| segment_to_h(s) },
        total_downloaded: total_downloaded,
        overall_percent: overall_percent
      }
    end

    # Total bytes downloaded across all segments
    #
    # @return [Integer] Total bytes downloaded
    def total_downloaded
      segments.sum(&:downloaded)
    end

    # Overall download percentage
    #
    # @return [Float] Percentage complete (0.0 to 100.0)
    def overall_percent
      return 0.0 if total_size.nil? || total_size <= 0
      ((total_downloaded.to_f / total_size) * 100).round(1)
    end

    private

    def build_segments(segment_data)
      return if segment_data.empty?

      # Sort by index to ensure correct order
      sorted_indices = segment_data.keys.sort

      sorted_indices.each_with_index do |idx, position|
        data = segment_data[idx]
        next unless data[:pos] && data[:limit]

        # Calculate start position: segment 0 starts at 0, others start at previous segment's limit
        start = if position.zero?
                  0
                else
                  prev_idx = sorted_indices[position - 1]
                  segment_data[prev_idx][:limit]
                end

        @segments << Segment.new(
          index: idx,
          pos: data[:pos],
          limit: data[:limit],
          start: start
        )
      end
    end

    def segment_to_h(segment)
      {
        index: segment.index,
        pos: segment.pos,
        limit: segment.limit,
        start: segment.start,
        downloaded: segment.downloaded,
        segment_size: segment.segment_size,
        percent: segment.percent
      }
    end
  end
end
