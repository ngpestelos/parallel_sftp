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
        .with(anything, on_progress: nil, on_segment_progress: nil)
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
        .with(anything, on_progress: progress_callback, on_segment_progress: nil)
        .and_return(download_mock)

      client.download(remote_path, local_path, on_progress: progress_callback)
    end

    it "passes segment progress callback to Download" do
      download_mock = instance_double(ParallelSftp::Download, execute: local_path)
      segment_callback = ->(info) { puts info[:segments] }

      expect(ParallelSftp::Download).to receive(:new)
        .with(anything, on_progress: nil, on_segment_progress: segment_callback)
        .and_return(download_mock)

      client.download(remote_path, local_path, on_segment_progress: segment_callback)
    end

    it "returns the local path on success" do
      download_mock = instance_double(ParallelSftp::Download, execute: local_path)
      allow(ParallelSftp::Download).to receive(:new).and_return(download_mock)

      result = client.download(remote_path, local_path)

      expect(result).to eq(local_path)
    end

    context "with retry on corruption" do
      let(:zip_error) { ParallelSftp::ZipIntegrityError.new(path: local_path, output: "corrupted") }

      before do
        allow(FileUtils).to receive(:rm_f)
      end

      it "retries with same segments on first corruption" do
        call_count = 0
        allow(ParallelSftp::Download).to receive(:new) do
          download_mock = instance_double(ParallelSftp::Download)
          allow(download_mock).to receive(:execute) do
            call_count += 1
            raise zip_error if call_count == 1

            local_path
          end
          download_mock
        end

        result = client.download(remote_path, local_path, segments: 4)
        expect(result).to eq(local_path)
        expect(call_count).to eq(2)
      end

      it "cleans up corrupted files before retry" do
        call_count = 0
        allow(ParallelSftp::Download).to receive(:new) do
          download_mock = instance_double(ParallelSftp::Download)
          allow(download_mock).to receive(:execute) do
            call_count += 1
            raise zip_error if call_count == 1

            local_path
          end
          download_mock
        end

        expect(FileUtils).to receive(:rm_f).with(local_path)
        expect(FileUtils).to receive(:rm_f).with("#{local_path}.lftp-pget-status")

        client.download(remote_path, local_path, segments: 4)
      end

      it "reduces segments after exhausting parallel retries" do
        segments_used = []
        call_count = 0

        allow(ParallelSftp::LftpCommand).to receive(:new) do |opts|
          segments_used << opts[:segments]
          instance_double(ParallelSftp::LftpCommand)
        end

        allow(ParallelSftp::Download).to receive(:new) do
          download_mock = instance_double(ParallelSftp::Download)
          allow(download_mock).to receive(:execute) do
            call_count += 1
            # Fail first 2 attempts (parallel_retries default), succeed on 3rd with reduced segments
            raise zip_error if call_count <= 2

            local_path
          end
          download_mock
        end

        client.download(remote_path, local_path, segments: 4, parallel_retries: 2)

        # First 2 with 4 segments, then 1 with 2 segments
        expect(segments_used).to eq([4, 4, 2])
      end

      it "raises error after all retries exhausted with segments=1" do
        allow(ParallelSftp::Download).to receive(:new) do
          download_mock = instance_double(ParallelSftp::Download)
          allow(download_mock).to receive(:execute).and_raise(zip_error)
          download_mock
        end

        expect do
          client.download(remote_path, local_path, segments: 2, parallel_retries: 1)
        end.to raise_error(ParallelSftp::ZipIntegrityError)
      end

      it "skips retry logic when retry_on_corruption is false" do
        download_mock = instance_double(ParallelSftp::Download)
        allow(download_mock).to receive(:execute).and_raise(zip_error)
        allow(ParallelSftp::Download).to receive(:new).and_return(download_mock)

        expect(FileUtils).not_to receive(:rm_f)

        expect do
          client.download(remote_path, local_path, retry_on_corruption: false)
        end.to raise_error(ParallelSftp::ZipIntegrityError)
      end
    end
  end
end
