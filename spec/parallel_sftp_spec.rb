# frozen_string_literal: true

RSpec.describe ParallelSftp do
  it "has a version number" do
    expect(ParallelSftp::VERSION).not_to be nil
  end

  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(ParallelSftp.configuration).to be_a(ParallelSftp::Configuration)
    end

    it "returns the same instance on multiple calls" do
      config1 = ParallelSftp.configuration
      config2 = ParallelSftp.configuration
      expect(config1).to be(config2)
    end
  end

  describe ".configure" do
    it "yields the configuration" do
      ParallelSftp.configure do |config|
        config.default_segments = 16
        config.timeout = 120
      end

      expect(ParallelSftp.configuration.default_segments).to eq(16)
      expect(ParallelSftp.configuration.timeout).to eq(120)
    end
  end

  describe ".reset_configuration!" do
    it "resets to default values" do
      ParallelSftp.configure do |config|
        config.default_segments = 16
      end

      ParallelSftp.reset_configuration!

      expect(ParallelSftp.configuration.default_segments).to eq(4)
    end
  end

  describe ".lftp_available?" do
    it "returns a boolean" do
      expect(ParallelSftp.lftp_available?).to be(true).or be(false)
    end
  end

  describe ".lftp_version" do
    context "when lftp is available" do
      before do
        allow(ParallelSftp).to receive(:lftp_available?).and_return(true)
        allow(ParallelSftp).to receive(:`).with("lftp --version").and_return("LFTP | Version 4.9.2\n")
      end

      it "returns the version string" do
        expect(ParallelSftp.lftp_version).to eq("LFTP | Version 4.9.2")
      end
    end

    context "when lftp is not available" do
      before do
        allow(ParallelSftp).to receive(:lftp_available?).and_return(false)
      end

      it "returns nil" do
        expect(ParallelSftp.lftp_version).to be_nil
      end
    end
  end

  describe ".ensure_lftp_available!" do
    context "when lftp is available" do
      before do
        allow(ParallelSftp).to receive(:lftp_available?).and_return(true)
      end

      it "does not raise an error" do
        expect { ParallelSftp.ensure_lftp_available! }.not_to raise_error
      end
    end

    context "when lftp is not available" do
      before do
        allow(ParallelSftp).to receive(:lftp_available?).and_return(false)
      end

      it "raises LftpNotFoundError" do
        expect { ParallelSftp.ensure_lftp_available! }.to raise_error(ParallelSftp::LftpNotFoundError)
      end
    end
  end
end
