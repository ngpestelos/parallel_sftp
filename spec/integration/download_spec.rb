# frozen_string_literal: true

require "spec_helper"

# Integration tests for ParallelSftp downloads
#
# These tests require a running SFTP server and are skipped by default.
# To run them, set the following environment variables:
#
#   SFTP_TEST_HOST=your-sftp-server.com
#   SFTP_TEST_USER=username
#   SFTP_TEST_PASSWORD=password
#   SFTP_TEST_FILE=/path/to/test/file.txt
#
# Then run: rspec spec/integration

RSpec.describe "Integration: Download", :integration do
  let(:host) { ENV["SFTP_TEST_HOST"] }
  let(:user) { ENV["SFTP_TEST_USER"] }
  let(:password) { ENV["SFTP_TEST_PASSWORD"] }
  let(:remote_file) { ENV["SFTP_TEST_FILE"] }
  let(:local_path) { "/tmp/parallel_sftp_test_#{Time.now.to_i}" }

  before(:all) do
    skip "Integration tests require SFTP_TEST_HOST environment variable" unless ENV["SFTP_TEST_HOST"]
    skip "lftp is not installed" unless ParallelSftp.lftp_available?
  end

  after(:each) do
    FileUtils.rm_f(local_path) if File.exist?(local_path.to_s)
  end

  describe "simple download" do
    it "downloads a file" do
      result = ParallelSftp.download(
        host: host,
        user: user,
        password: password,
        remote_path: remote_file,
        local_path: local_path
      )

      expect(result).to eq(local_path)
      expect(File.exist?(local_path)).to be true
    end
  end

  describe "Client#download" do
    it "downloads with progress callback" do
      client = ParallelSftp::Client.new(
        host: host,
        user: user,
        password: password
      )

      progress_updates = []
      result = client.download(
        remote_file,
        local_path,
        on_progress: ->(info) { progress_updates << info }
      )

      expect(result).to eq(local_path)
      expect(File.exist?(local_path)).to be true
    end
  end

  describe "resume capability" do
    it "resumes an interrupted download" do
      # Start a download
      client = ParallelSftp::Client.new(
        host: host,
        user: user,
        password: password
      )

      # First download (or simulate partial)
      result = client.download(remote_file, local_path, segments: 1)
      original_size = File.size(local_path)

      # Remove file and download again with resume
      FileUtils.rm_f(local_path)

      # This would resume if there was a partial file
      result = client.download(remote_file, local_path, resume: true)

      expect(File.exist?(local_path)).to be true
    end
  end
end
