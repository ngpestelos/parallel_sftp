# frozen_string_literal: true

require "parallel_sftp/version"
require "parallel_sftp/errors"
require "parallel_sftp/configuration"
require "parallel_sftp/lftp_command"
require "parallel_sftp/progress_parser"
require "parallel_sftp/download"
require "parallel_sftp/client"

module ParallelSftp
  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    # Configure ParallelSftp globally
    #
    # @example
    #   ParallelSftp.configure do |config|
    #     config.default_segments = 8
    #     config.timeout = 60
    #     config.max_retries = 15
    #   end
    def configure
      yield(configuration)
    end

    # Reset configuration to defaults
    def reset_configuration!
      @configuration = Configuration.new
    end

    # Check if lftp is available on the system
    #
    # @return [Boolean] true if lftp is installed and accessible
    def lftp_available?
      system("which lftp > /dev/null 2>&1")
    end

    # Get the installed lftp version
    #
    # @return [String, nil] Version string or nil if not installed
    def lftp_version
      return nil unless lftp_available?
      `lftp --version`.lines.first&.strip
    end

    # Raise an error if lftp is not available
    #
    # @raise [LftpNotFoundError] if lftp is not installed
    def ensure_lftp_available!
      raise LftpNotFoundError unless lftp_available?
    end

    # Simple one-liner for downloading a file
    #
    # @param options [Hash] Connection and download options
    # @option options [String] :host SFTP host
    # @option options [String] :user Username
    # @option options [String] :password Password
    # @option options [Integer] :port SFTP port (default: 22)
    # @option options [String] :remote_path Path to file on server
    # @option options [String] :local_path Local destination path
    # @option options [Integer] :segments Parallel connections (default: 4)
    # @option options [Boolean] :resume Continue interrupted downloads (default: true)
    # @option options [Integer] :timeout Connection timeout in seconds
    # @option options [Integer] :max_retries Maximum retry attempts
    # @option options [Proc] :on_progress Progress callback
    #
    # @return [String] Local path to downloaded file
    # @raise [DownloadError] if download fails
    #
    # @example
    #   ParallelSftp.download(
    #     host: 'ftp.example.com',
    #     user: 'username',
    #     password: 'secret',
    #     remote_path: '/path/to/large_file.zip',
    #     local_path: '/tmp/large_file.zip',
    #     segments: 8,
    #     on_progress: ->(info) { puts "#{info[:percent]}%" }
    #   )
    def download(options = {})
      client = Client.new(
        host: options.fetch(:host),
        user: options.fetch(:user),
        password: options.fetch(:password),
        port: options.fetch(:port, configuration.default_port)
      )

      client.download(
        options.fetch(:remote_path),
        options.fetch(:local_path),
        segments: options[:segments],
        resume: options.fetch(:resume, true),
        timeout: options[:timeout],
        max_retries: options[:max_retries],
        reconnect_interval: options[:reconnect_interval],
        sftp_connect_program: options[:sftp_connect_program],
        on_progress: options[:on_progress]
      )
    end
  end
end
