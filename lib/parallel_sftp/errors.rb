# frozen_string_literal: true

module ParallelSftp
  # Base error class for all ParallelSftp errors
  class Error < StandardError; end

  # Raised when lftp is not installed or not found in PATH
  class LftpNotFoundError < Error
    def initialize(msg = "lftp is not installed or not found in PATH. Install with: brew install lftp (macOS) or apt install lftp (Linux)")
      super
    end
  end

  # Raised when SFTP connection fails
  class ConnectionError < Error
    attr_reader :host, :exit_status

    def initialize(msg = nil, host: nil, exit_status: nil)
      @host = host
      @exit_status = exit_status
      super(msg || "Failed to connect to SFTP server#{host ? ": #{host}" : ""}")
    end
  end

  # Raised when file download fails
  class DownloadError < Error
    attr_reader :remote_path, :exit_status, :output

    def initialize(msg = nil, remote_path: nil, exit_status: nil, output: nil)
      @remote_path = remote_path
      @exit_status = exit_status
      @output = output
      super(msg || "Failed to download file#{remote_path ? ": #{remote_path}" : ""}")
    end
  end

  # Raised when downloaded file integrity check fails
  class IntegrityError < Error
    attr_reader :expected_size, :actual_size

    def initialize(msg = nil, expected_size: nil, actual_size: nil)
      @expected_size = expected_size
      @actual_size = actual_size
      super(msg || "File integrity check failed. Expected: #{expected_size}, Got: #{actual_size}")
    end
  end
end
