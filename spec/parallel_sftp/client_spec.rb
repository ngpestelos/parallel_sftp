# frozen_string_literal: true

require "spec_helper"

RSpec.describe ParallelSftp::Client do
  let(:client_options) do
    {
      host: "sftp.example.com",
      user: "testuser",
      password: "secret123"
    }
  end

  subject(:client) { described_class.new(client_options) }

  describe "#initialize" do
    it "stores connection details" do
      expect(client.host).to eq("sftp.example.com")
      expect(client.user).to eq("testuser")
      expect(client.password).to eq("secret123")
    end

    it "uses default port" do
      expect(client.port).to eq(22)
    end

    it "allows custom port" do
      custom_client = described_class.new(client_options.merge(port: 2222))
      expect(custom_client.port).to eq(2222)
    end
  end

  describe "#download" do
    let(:remote_path) { "/data/file.zip" }
    let(:local_path) { "/tmp/file.zip" }

    before do
      allow(ParallelSftp).to receive(:lftp_available?).and_return(true)
    end

    it "creates an LftpCommand with correct options" do
      download_mock = instance_double(ParallelSftp::Download, execute: local_path)

      expect(ParallelSftp::LftpCommand).to receive(:new).with(
        hash_including(
          host: "sftp.example.com",
          user: "testuser",
          password: "secret123",
          port: 22,
          remote_path: remote_path,
          local_path: local_path
        )
      ).and_call_original

      expect(ParallelSftp::Download).to receive(:new)
        .with(anything, on_progress: nil)
        .and_return(download_mock)

      client.download(remote_path, local_path)
    end

    it "passes custom options to LftpCommand" do
      download_mock = instance_double(ParallelSftp::Download, execute: local_path)

      expect(ParallelSftp::LftpCommand).to receive(:new).with(
        hash_including(
          segments: 8,
          resume: false,
          timeout: 60,
          max_retries: 15
        )
      ).and_call_original

      allow(ParallelSftp::Download).to receive(:new).and_return(download_mock)

      client.download(remote_path, local_path,
        segments: 8,
        resume: false,
        timeout: 60,
        max_retries: 15
      )
    end

    it "passes progress callback to Download" do
      download_mock = instance_double(ParallelSftp::Download, execute: local_path)
      progress_callback = ->(info) { puts info }

      expect(ParallelSftp::Download).to receive(:new)
        .with(anything, on_progress: progress_callback)
        .and_return(download_mock)

      client.download(remote_path, local_path, on_progress: progress_callback)
    end

    it "returns the local path on success" do
      download_mock = instance_double(ParallelSftp::Download, execute: local_path)
      allow(ParallelSftp::Download).to receive(:new).and_return(download_mock)

      result = client.download(remote_path, local_path)

      expect(result).to eq(local_path)
    end
  end
end
