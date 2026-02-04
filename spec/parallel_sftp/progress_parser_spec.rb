# frozen_string_literal: true

require "spec_helper"

RSpec.describe ParallelSftp::ProgressParser do
  subject(:parser) { described_class.new }

  describe "#initialize" do
    it "starts with zero values" do
      expect(parser.bytes_transferred).to eq(0)
      expect(parser.total_bytes).to eq(0)
      expect(parser.speed).to eq(0)
      expect(parser.percent).to eq(0)
      expect(parser.eta).to be_nil
    end
  end

  describe "#parse" do
    it "returns false for empty lines" do
      expect(parser.parse("")).to be false
      expect(parser.parse("   ")).to be false
      expect(parser.parse(nil)).to be false
    end

    it "extracts percentage" do
      parser.parse("Downloading file... 45%")

      expect(parser.percent).to eq(45)
    end

    it "extracts speed in KB/s" do
      parser.parse("500.5 KB/s")

      expect(parser.speed).to eq(512_512)  # 500.5 * 1024
    end

    it "extracts speed in MB/s" do
      parser.parse("10.5 MB/s")

      expect(parser.speed).to eq(11_010_048)  # 10.5 * 1024 * 1024
    end

    it "extracts bytes transferred and total" do
      parser.parse("1.5GB of 20GB")

      expect(parser.bytes_transferred).to eq(1_610_612_736)  # 1.5 * 1024^3
      expect(parser.total_bytes).to eq(21_474_836_480)       # 20 * 1024^3
    end

    it "extracts ETA" do
      parser.parse("eta: 5m30s")

      expect(parser.eta).to eq("5m30s")
    end

    it "extracts multiple values from a complex line" do
      parser.parse("pget: /file.zip: 1.5GB of 20GB (7%) 10.5MB/s eta: 30m")

      expect(parser.percent).to eq(7)
      expect(parser.speed).to eq(11_010_048)
      expect(parser.eta).to eq("30m")
    end

    it "returns true when progress was updated" do
      expect(parser.parse("45%")).to be true
    end

    it "returns false when no progress info found" do
      expect(parser.parse("Some random log message")).to be false
    end
  end

  describe "#to_h" do
    it "returns a hash with all progress info" do
      parser.parse("1.5GB of 20GB (7%) 10.5MB/s eta: 30m")

      result = parser.to_h

      expect(result).to include(
        bytes_transferred: be_a(Integer),
        total_bytes: be_a(Integer),
        speed: be_a(Integer),
        percent: 7,
        eta: "30m"
      )
    end
  end
end
