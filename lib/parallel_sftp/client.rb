# frozen_string_literal: true

require "fileutils"

module ParallelSftp
  # SFTP client for parallel downloads
  class Client
    attr_reader :host, :user, :password, :port

    # Default number of times to retry with same segment count before reducing
    DEFAULT_PARALLEL_RETRIES = 2

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
    # @option options [Proc] :on_segment_progress Per-segment progress callback receiving hash with
    #   :total_size, :segments, :total_downloaded, :overall_percent, :speed, :eta, :elapsed
    # @option options [Boolean] :retry_on_corruption Auto-retry on zip corruption (default: true)
    # @option options [Integer] :parallel_retries Times to retry with same segments before reducing (default: 2)
    #
    # @return [String] Local path to the downloaded file
    # @raise [DownloadError] if download fails
    # @raise [ZipIntegrityError] if zip corruption persists after all retries
    def download(remote_path, local_path, options = {})
      segments = options.fetch(:segments, ParallelSftp.configuration.default_segments)
      retry_on_corruption = options.fetch(:retry_on_corruption, true)
      parallel_retries = options.fetch(:parallel_retries, DEFAULT_PARALLEL_RETRIES)

      return execute_download(remote_path, local_path, options.merge(segments: segments)) unless retry_on_corruption

      download_with_retry(remote_path, local_path, options, segments, parallel_retries)
    end

    private

    def download_with_retry(remote_path, local_path, options, segments, parallel_retries)
      current_segments = segments
      retries_at_current_segments = 0

      loop do
        begin
          return execute_download(remote_path, local_path, options.merge(segments: current_segments, resume: false))
        rescue ZipIntegrityError => e
          cleanup_corrupted_download(local_path)

          retries_at_current_segments += 1

          if retries_at_current_segments < parallel_retries
            warn "[parallel_sftp] Zip corruption detected, retrying with #{current_segments} segments " \
                 "(attempt #{retries_at_current_segments + 1}/#{parallel_retries})..."
          elsif current_segments > 1
            # Reduce segments and reset retry counter
            current_segments = (current_segments / 2).clamp(1, current_segments - 1)
            retries_at_current_segments = 0
            warn "[parallel_sftp] Zip corruption persists, reducing to #{current_segments} segments..."
          else
            # segments = 1 and still failing, give up
            raise e
          end
        end
      end
    end

    def cleanup_corrupted_download(local_path)
      FileUtils.rm_f(local_path)
      FileUtils.rm_f("#{local_path}.lftp-pget-status")
    end

    def execute_download(remote_path, local_path, options)
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
        reconnect_interval: options.fetch(:reconnect_interval, ParallelSftp.configuration.reconnect_interval),
        sftp_connect_program: options[:sftp_connect_program]
      )

      download = Download.new(
        lftp_command,
        on_progress: options[:on_progress],
        on_segment_progress: options[:on_segment_progress]
      )
      download.execute
    end
  end
end
