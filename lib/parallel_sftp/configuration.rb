# frozen_string_literal: true

module ParallelSftp
  class Configuration
    # Number of parallel connections for segmented download
    attr_accessor :default_segments

    # Connection timeout in seconds
    attr_accessor :timeout

    # Maximum retry attempts
    attr_accessor :max_retries

    # Seconds to wait between reconnection attempts
    attr_accessor :reconnect_interval

    # Default SFTP port
    attr_accessor :default_port

    # Custom SSH connect program for lftp (e.g., for legacy host key algorithms)
    # Example: "ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa"
    attr_accessor :sftp_connect_program

    def initialize
      @default_segments = 4
      @timeout = 30
      @max_retries = 10
      @reconnect_interval = 5
      @default_port = 22
      @sftp_connect_program = nil
    end

    # Apply large file optimizations (20GB+)
    def optimize_for_large_files!
      @default_segments = 8
      @timeout = 60
      @max_retries = 15
      @reconnect_interval = 10
    end
  end
end
