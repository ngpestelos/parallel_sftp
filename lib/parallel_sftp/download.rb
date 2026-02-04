# frozen_string_literal: true

require "open3"
require "fileutils"

module ParallelSftp
  # Executes lftp downloads with progress tracking
  class Download
    attr_reader :lftp_command, :on_progress, :output_buffer

    def initialize(lftp_command, on_progress: nil)
      @lftp_command = lftp_command
      @on_progress = on_progress
      @output_buffer = []
      @progress_parser = ProgressParser.new
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

      Open3.popen2e(*lftp_command.to_command) do |stdin, stdout_stderr, wait_thr|
        stdin.close

        stdout_stderr.each_line do |line|
          @output_buffer << line
          process_output_line(line)
        end

        exit_status = wait_thr.value
      end

      handle_result(exit_status)
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
