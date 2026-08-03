# frozen_string_literal: true

module ParallelSftp
  # Builds lftp command scripts for SFTP downloads
  class LftpCommand
    # Characters that can break out of double-quoted lftp script interpolation.
    UNSAFE_PATH_CHARS = /["`\\\n\r\0]|!|\$\(|\$\{/
    # Host: hostname, IPv4, or bracketed IPv6
    HOST_PATTERN = /\A(?:[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?|\d{1,3}(?:\.\d{1,3}){3}|\[[0-9a-fA-F:.]+\])\z/
    # Positive allowlist of OpenSSH -o keys permitted in sftp_connect_program.
    # Intentionally excludes command-running options (ProxyCommand, LocalCommand,
    # RemoteCommand, KnownHostsCommand, PermitLocalCommand, etc.).
    ALLOWED_CONNECT_PROGRAM_OPTIONS = %w[
      HostKeyAlgorithms
      PubkeyAcceptedKeyTypes
      PubkeyAcceptedAlgorithms
      StrictHostKeyChecking
      UserKnownHostsFile
      KexAlgorithms
      Ciphers
      MACs
    ].freeze
    # Safe value charset for allowlisted -o options (no spaces/quotes/shell meta).
    CONNECT_PROGRAM_OPTION_VALUE = /\A[A-Za-z0-9_+=.,@%\/-]+\z/

    attr_reader :host, :user, :password, :port, :remote_path, :local_path,
                :segments, :timeout, :max_retries, :reconnect_interval, :resume,
                :sftp_connect_program

    def initialize(options = {})
      @host = options.fetch(:host)
      @user = options.fetch(:user)
      @password = options.fetch(:password)
      @port = Integer(options.fetch(:port, ParallelSftp.configuration.default_port))
      @remote_path = options.fetch(:remote_path)
      @local_path = options.fetch(:local_path)
      @segments = Integer(options.fetch(:segments, ParallelSftp.configuration.default_segments))
      @timeout = Integer(options.fetch(:timeout, ParallelSftp.configuration.timeout))
      @max_retries = Integer(options.fetch(:max_retries, ParallelSftp.configuration.max_retries))
      @reconnect_interval = Integer(options.fetch(:reconnect_interval, ParallelSftp.configuration.reconnect_interval))
      @resume = options.fetch(:resume, true)
      @sftp_connect_program = options.fetch(:sftp_connect_program,
        ParallelSftp.configuration.sftp_connect_program)

      validate!
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

      lines << "open -p #{port} sftp://#{escaped_user}:#{escaped_password}@#{host}"
      lines << "pget -n #{segments}#{resume_flag} \"#{remote_path}\" -o \"#{local_path}\""
      lines << "quit"

      lines.join("\n") + "\n"
    end

    # Generate the full lftp command with script
    def to_command
      ["lftp", "-c", to_script]
    end

    private

    def validate!
      validate_host!
      validate_user!
      validate_path!(remote_path, :remote_path)
      validate_path!(local_path, :local_path)
      validate_connect_program!
      raise ArgumentError, "port must be between 1 and 65535" unless port.between?(1, 65_535)
      raise ArgumentError, "segments must be >= 1" unless segments >= 1
      raise ArgumentError, "timeout must be >= 0" unless timeout >= 0
      raise ArgumentError, "max_retries must be >= 0" unless max_retries >= 0
      raise ArgumentError, "reconnect_interval must be >= 0" unless reconnect_interval >= 0
    end

    def validate_host!
      host_s = host.to_s
      raise ArgumentError, "host is required" if host_s.empty?
      return if host_s.match?(HOST_PATTERN)

      raise ArgumentError, "host has invalid format (hostname, IPv4, or [IPv6] only)"
    end

    def validate_user!
      user_s = user.to_s
      raise ArgumentError, "user is required" if user_s.empty?
      raise ArgumentError, "user contains disallowed characters" if user_s.match?(/[\n\r\0@\/]/)
    end

    def validate_path!(path, name)
      path_s = path.to_s
      raise ArgumentError, "#{name} is required" if path_s.empty?
      if path_s.match?(UNSAFE_PATH_CHARS)
        raise ArgumentError,
          "#{name} contains characters that cannot be safely embedded in an lftp script " \
          "(quotes, backslash, newlines, !, or shell expansions)"
      end
    end

    def validate_connect_program!
      return if sftp_connect_program.nil?

      tokens = sftp_connect_program.to_s.split(/\s+/)
      unless tokens.first == "ssh"
        raise ArgumentError,
          "sftp_connect_program must be an allowlisted ssh -o ... form " \
          "(binary must be ssh; no quotes or shell metacharacters)"
      end

      i = 1
      while i < tokens.length
        unless tokens[i] == "-o"
          raise ArgumentError,
            "sftp_connect_program only allows -o key=value after ssh " \
            "(got #{tokens[i].inspect})"
        end
        i += 1
        if i >= tokens.length
          raise ArgumentError, "sftp_connect_program: -o requires key=value"
        end

        key, sep, value = tokens[i].partition("=")
        unless sep == "=" && !key.empty? && !value.empty?
          raise ArgumentError,
            "sftp_connect_program: -o requires key=value (got #{tokens[i].inspect})"
        end
        unless allowlisted_connect_option?(key)
          raise ArgumentError,
            "sftp_connect_program: ssh -o option #{key.inspect} is not allowlisted " \
            "(allowed: #{ALLOWED_CONNECT_PROGRAM_OPTIONS.join(', ')})"
        end
        unless value.match?(CONNECT_PROGRAM_OPTION_VALUE)
          raise ArgumentError,
            "sftp_connect_program: invalid characters in option value for #{key}"
        end
        i += 1
      end
    end

    def allowlisted_connect_option?(key)
      ALLOWED_CONNECT_PROGRAM_OPTIONS.any? { |allowed| allowed.casecmp?(key) }
    end

    def escaped_user
      # URL-encode user for sftp://user:pass@host (password already encoded)
      user.to_s.gsub(/[^a-zA-Z0-9_.~-]/) { |c| format("%%%02X", c.ord) }
    end

    def escaped_password
      # Escape special characters in password for URL
      password.to_s.gsub(/[^a-zA-Z0-9_.-]/) { |c| format("%%%02X", c.ord) }
    end

    def resume_flag
      resume ? " -c" : ""
    end
  end
end
