# frozen_string_literal: true

module ParallelSftp
  # Builds lftp command scripts for SFTP downloads
  class LftpCommand
    attr_reader :host, :user, :password, :port, :remote_path, :local_path,
                :segments, :timeout, :max_retries, :reconnect_interval, :resume,
                :sftp_connect_program

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
      @sftp_connect_program = options.fetch(:sftp_connect_program,
        ParallelSftp.configuration.sftp_connect_program)
    end

    # Generate the lftp script for download
    def to_script
      lines = [
        "set net:timeout #{timeout}",
        "set net:max-retries #{max_retries}",
        "set net:reconnect-interval-base #{reconnect_interval}",
        "set sftp:auto-confirm yes",
        "set ssl:verify-certificate no",
        "set xfer:clobber on"
      ]

      # Add custom SSH connect program if configured (for legacy host key algorithms)
      if sftp_connect_program
        lines << "set sftp:connect-program \"#{sftp_connect_program}\""
      end

      lines << "open -p #{port} sftp://#{user}:#{escaped_password}@#{host}"
      lines << "pget -n #{segments}#{resume_flag} \"#{remote_path}\" -o \"#{local_path}\""
      lines << "quit"

      lines.join("\n") + "\n"
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
