# frozen_string_literal: true

require "open3"
require "fileutils"

module ParallelSftp
  # Executes lftp downloads with progress tracking
  class Download
    attr_reader :lftp_command, :on_progress, :on_segment_progress, :output_buffer

    # Default interval for polling the status file (in seconds)
    DEFAULT_POLL_INTERVAL = 1

    def initialize(lftp_command, on_progress: nil, on_segment_progress: nil)
      @lftp_command = lftp_command
      @on_progress = on_progress
      @on_segment_progress = on_segment_progress
      @output_buffer = []
      @progress_parser = ProgressParser.new
      @segment_parser = SegmentProgressParser.new
      @time_estimator = TimeEstimator.new
      @polling_thread = nil
      @stop_polling = false
    end

    # Execute the download
    # Returns the local file path on success
    # Raises DownloadError on failure
    def execute
      ParallelSftp.ensure_lftp_available!

      # Ensure local directory exists
      FileUtils.mkdir_p(File.dirname(lftp_command.local_path))

      run_lftp
    end

    private

    def run_lftp
      exit_status = nil
      status_file = status_file_path

      Open3.popen2e(*lftp_command.to_command) do |stdin, stdout_stderr, wait_thr|
        stdin.close

        # Start background polling for segment progress
        start_segment_polling(status_file) if on_segment_progress

        stdout_stderr.each_line do |line|
          @output_buffer << line
          process_output_line(line)
        end

        exit_status = wait_thr.value
      end

      stop_segment_polling
      handle_result(exit_status)
    end

    def status_file_path
      "#{lftp_command.local_path}.lftp-pget-status"
    end

    def start_segment_polling(status_file)
      @stop_polling = false
      @polling_thread = Thread.new do
        poll_segment_progress(status_file)
      end
    end

    def stop_segment_polling
      @stop_polling = true
      if @polling_thread&.alive?
        @polling_thread.join(2) # Wait up to 2 seconds for clean shutdown
        @polling_thread.kill if @polling_thread.alive?
      end
    end

    def poll_segment_progress(status_file)
      until @stop_polling
        sleep DEFAULT_POLL_INTERVAL

        begin
          next unless File.exist?(status_file)

          if @segment_parser.parse(status_file)
            progress = build_segment_progress
            on_segment_progress&.call(progress)
          end
        rescue StandardError
          # Silently continue on parse errors - the file may be mid-write
        end
      end
    end

    def build_segment_progress
      progress = @segment_parser.to_h
      total_downloaded = progress[:total_downloaded]
      total_size = progress[:total_size]

      # Record sample for time estimation
      @time_estimator.record(total_downloaded)

      # Add calculated time estimates
      progress[:speed] = @time_estimator.speed_bytes_per_second
      progress[:eta] = @time_estimator.eta_formatted(total_size, total_downloaded) if total_size && total_size > 0
      progress[:elapsed] = @time_estimator.elapsed_seconds
      progress[:average_speed] = @time_estimator.average_speed

      progress
    end

    def process_output_line(line)
      return unless on_progress

      if @progress_parser.parse(line)
        on_progress.call(@progress_parser.to_h)
      end
    end

    def handle_result(exit_status)
      if exit_status.success?
        verify_download
        lftp_command.local_path
      else
        raise DownloadError.new(
          "lftp exited with status #{exit_status.exitstatus}",
          remote_path: lftp_command.remote_path,
          exit_status: exit_status.exitstatus,
          output: @output_buffer.join
        )
      end
    end

    def verify_download
      unless File.exist?(lftp_command.local_path)
        raise DownloadError.new(
          "Downloaded file not found at expected location",
          remote_path: lftp_command.remote_path,
          output: @output_buffer.join
        )
      end
    end
  end
end
