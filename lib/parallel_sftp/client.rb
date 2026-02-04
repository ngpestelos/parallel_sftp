# frozen_string_literal: true

module ParallelSftp
  # SFTP client for parallel downloads
  class Client
    attr_reader :host, :user, :password, :port

    def initialize(options = {})
      @host = options.fetch(:host)
      @user = options.fetch(:user)
      @password = options.fetch(:password)
      @port = options.fetch(:port, ParallelSftp.configuration.default_port)
    end

    # Download a file from the remote server
    #
    # @param remote_path [String] Path to the file on the remote server
    # @param local_path [String] Local path to save the file
    # @param options [Hash] Download options
    # @option options [Integer] :segments Number of parallel connections (default: 4)
    # @option options [Boolean] :resume Continue interrupted downloads (default: true)
    # @option options [Integer] :timeout Connection timeout in seconds (default: 30)
    # @option options [Integer] :max_retries Maximum retry attempts (default: 10)
    # @option options [Integer] :reconnect_interval Seconds between retries (default: 5)
    # @option options [Proc] :on_progress Progress callback receiving hash with :percent, :speed, etc.
    #
    # @return [String] Local path to the downloaded file
    # @raise [DownloadError] if download fails
    def download(remote_path, local_path, options = {})
      lftp_command = LftpCommand.new(
        host: host,
        user: user,
        password: password,
        port: port,
        remote_path: remote_path,
        local_path: local_path,
        segments: options.fetch(:segments, ParallelSftp.configuration.default_segments),
        resume: options.fetch(:resume, true),
        timeout: options.fetch(:timeout, ParallelSftp.configuration.timeout),
        max_retries: options.fetch(:max_retries, ParallelSftp.configuration.max_retries),
        reconnect_interval: options.fetch(:reconnect_interval, ParallelSftp.configuration.reconnect_interval)
      )

      download = Download.new(lftp_command, on_progress: options[:on_progress])
      download.execute
    end
  end
end
