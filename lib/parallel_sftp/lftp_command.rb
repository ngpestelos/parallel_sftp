# frozen_string_literal: true

module ParallelSftp
  # Builds lftp command scripts for SFTP downloads
  class LftpCommand
    attr_reader :host, :user, :password, :port, :remote_path, :local_path,
                :segments, :timeout, :max_retries, :reconnect_interval, :resume

    def initialize(options = {})
      @host = options.fetch(:host)
      @user = options.fetch(:user)
      @password = options.fetch(:password)
      @port = options.fetch(:port, ParallelSftp.configuration.default_port)
      @remote_path = options.fetch(:remote_path)
      @local_path = options.fetch(:local_path)
      @segments = options.fetch(:segments, ParallelSftp.configuration.default_segments)
      @timeout = options.fetch(:timeout, ParallelSftp.configuration.timeout)
      @max_retries = options.fetch(:max_retries, ParallelSftp.configuration.max_retries)
      @reconnect_interval = options.fetch(:reconnect_interval, ParallelSftp.configuration.reconnect_interval)
      @resume = options.fetch(:resume, true)
    end

    # Generate the lftp script for download
    def to_script
      <<~LFTP
        set net:timeout #{timeout}
        set net:max-retries #{max_retries}
        set net:reconnect-interval-base #{reconnect_interval}
        set sftp:auto-confirm yes
        set ssl:verify-certificate no
        open -p #{port} sftp://#{user}:#{escaped_password}@#{host}
        pget -n #{segments}#{resume_flag} "#{remote_path}" -o "#{local_path}"
        quit
      LFTP
    end

    # Generate the full lftp command with script
    def to_command
      ["lftp", "-c", to_script]
    end

    private

    def escaped_password
      # Escape special characters in password for URL
      password.gsub(/[^a-zA-Z0-9_.-]/) { |c| format("%%%02X", c.ord) }
    end

    def resume_flag
      resume ? " -c" : ""
    end
  end
end
