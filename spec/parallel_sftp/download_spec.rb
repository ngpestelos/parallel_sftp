# frozen_string_literal: true

require "spec_helper"
require "fileutils"

RSpec.describe ParallelSftp::Download do
  let(:lftp_command) do
    instance_double(
      ParallelSftp::LftpCommand,
      to_command: ["lftp", "-c", "script"],
      local_path: "/tmp/test_file.zip",
      remote_path: "/remote/file.zip"
    )
  end

  subject(:download) { described_class.new(lftp_command) }

  before do
    allow(ParallelSftp).to receive(:lftp_available?).and_return(true)
    allow(FileUtils).to receive(:mkdir_p)
  end

  describe "#execute" do
    context "when lftp is not available" do
      before do
        allow(ParallelSftp).to receive(:lftp_available?).and_return(false)
      end

      it "raises LftpNotFoundError" do
        expect { download.execute }.to raise_error(ParallelSftp::LftpNotFoundError)
      end
    end

    context "when lftp succeeds" do
      let(:wait_thr) { instance_double(Process::Waiter, value: double(success?: true, exitstatus: 0)) }

      before do
        allow(Open3).to receive(:popen2e).and_yield(
          instance_double(IO, close: nil),
          StringIO.new("Downloading... 50%\nDone\n"),
          wait_thr
        )
        allow(File).to receive(:exist?).with("/tmp/test_file.zip").and_return(true)
      end

      it "returns the local path" do
        expect(download.execute).to eq("/tmp/test_file.zip")
      end

      it "creates the local directory" do
        expect(FileUtils).to receive(:mkdir_p).with("/tmp")
        download.execute
      end
    end

    context "when lftp fails" do
      let(:wait_thr) { instance_double(Process::Waiter, value: double(success?: false, exitstatus: 1)) }

      before do
        allow(Open3).to receive(:popen2e).and_yield(
          instance_double(IO, close: nil),
          StringIO.new("Error: connection failed\n"),
          wait_thr
        )
      end

      it "raises DownloadError with exit status" do
        expect { download.execute }.to raise_error(ParallelSftp::DownloadError) do |error|
          expect(error.exit_status).to eq(1)
          expect(error.remote_path).to eq("/remote/file.zip")
          expect(error.output).to include("Error: connection failed")
        end
      end
    end

    context "when file is not found after download" do
      let(:wait_thr) { instance_double(Process::Waiter, value: double(success?: true, exitstatus: 0)) }

      before do
        allow(Open3).to receive(:popen2e).and_yield(
          instance_double(IO, close: nil),
          StringIO.new("Done\n"),
          wait_thr
        )
        allow(File).to receive(:exist?).with("/tmp/test_file.zip").and_return(false)
      end

      it "raises DownloadError" do
        expect { download.execute }.to raise_error(ParallelSftp::DownloadError) do |error|
          expect(error.message).to include("not found")
        end
      end
    end
  end

  describe "progress callback" do
    let(:wait_thr) { instance_double(Process::Waiter, value: double(success?: true, exitstatus: 0)) }
    let(:progress_updates) { [] }
    let(:on_progress) { ->(info) { progress_updates << info } }

    subject(:download) { described_class.new(lftp_command, on_progress: on_progress) }

    before do
      allow(Open3).to receive(:popen2e).and_yield(
        instance_double(IO, close: nil),
        StringIO.new("Downloading... 25%\nDownloading... 50%\nDone\n"),
        wait_thr
      )
      allow(File).to receive(:exist?).with("/tmp/test_file.zip").and_return(true)
    end

    it "calls the progress callback with parsed info" do
      download.execute

      expect(progress_updates).not_to be_empty
      expect(progress_updates.first).to include(:percent)
    end
  end
end
