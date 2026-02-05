# frozen_string_literal: true

require "spec_helper"

RSpec.describe "ParallelSftp errors" do
  describe ParallelSftp::Error do
    it "is a StandardError" do
      expect(described_class.new).to be_a(StandardError)
    end
  end

  describe ParallelSftp::LftpNotFoundError do
    it "has a default message" do
      error = described_class.new
      expect(error.message).to include("lftp is not installed")
    end

    it "includes installation instructions" do
      error = described_class.new
      expect(error.message).to include("brew install lftp")
      expect(error.message).to include("apt install lftp")
    end
  end

  describe ParallelSftp::ConnectionError do
    it "has a default message" do
      error = described_class.new
      expect(error.message).to include("Failed to connect")
    end

    it "includes host when provided" do
      error = described_class.new(host: "example.com")
      expect(error.message).to include("example.com")
    end

    it "stores exit_status" do
      error = described_class.new(exit_status: 1)
      expect(error.exit_status).to eq(1)
    end
  end

  describe ParallelSftp::DownloadError do
    it "has a default message" do
      error = described_class.new
      expect(error.message).to include("Failed to download")
    end

    it "includes remote_path when provided" do
      error = described_class.new(remote_path: "/path/to/file.zip")
      expect(error.message).to include("/path/to/file.zip")
    end

    it "stores exit_status and output" do
      error = described_class.new(exit_status: 1, output: "error log")
      expect(error.exit_status).to eq(1)
      expect(error.output).to eq("error log")
    end
  end

  describe ParallelSftp::IntegrityError do
    it "has a default message with sizes" do
      error = described_class.new(expected_size: 1000, actual_size: 500)
      expect(error.message).to include("Expected: 1000")
      expect(error.message).to include("Got: 500")
    end

    it "stores size values" do
      error = described_class.new(expected_size: 1000, actual_size: 500)
      expect(error.expected_size).to eq(1000)
      expect(error.actual_size).to eq(500)
    end
  end

  describe ParallelSftp::ZipIntegrityError do
    it "is an IntegrityError" do
      expect(described_class.new).to be_a(ParallelSftp::IntegrityError)
    end

    it "has a default message" do
      error = described_class.new
      expect(error.message).to include("Zip integrity check failed")
    end

    it "includes path when provided" do
      error = described_class.new(path: "/tmp/file.zip")
      expect(error.message).to include("/tmp/file.zip")
    end

    it "stores path and output" do
      error = described_class.new(
        path: "/tmp/file.zip",
        output: "error: invalid compressed data"
      )
      expect(error.path).to eq("/tmp/file.zip")
      expect(error.output).to eq("error: invalid compressed data")
    end
  end
end
