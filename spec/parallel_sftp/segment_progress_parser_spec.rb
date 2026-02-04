# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe ParallelSftp::SegmentProgressParser do
  subject(:parser) { described_class.new }

  describe "#initialize" do
    it "starts with nil total_size" do
      expect(parser.total_size).to be_nil
    end

    it "starts with empty segments" do
      expect(parser.segments).to eq([])
    end
  end

  describe "#parse_content" do
    context "with valid 8-segment status" do
      let(:content) do
        <<~STATUS
          size=20955686931
          0.pos=57442304
          0.limit=2619460869
          1.pos=2670611717
          1.limit=5238921735
          2.pos=5293939207
          2.limit=7858382601
          3.pos=7918216969
          3.limit=10477843467
          4.pos=10536662027
          4.limit=13097304333
          5.pos=13157531917
          5.limit=15716765199
          6.pos=15765720591
          6.limit=18336226065
          7.pos=18394323729
          7.limit=20955686931
        STATUS
      end

      before { parser.parse_content(content) }

      it "parses total size" do
        expect(parser.total_size).to eq(20_955_686_931)
      end

      it "parses all 8 segments" do
        expect(parser.segments.size).to eq(8)
      end

      it "calculates segment 0 downloaded bytes correctly" do
        seg0 = parser.segments[0]
        expect(seg0.downloaded).to eq(57_442_304) # pos - start (0)
      end

      it "calculates segment 1 downloaded bytes correctly" do
        seg1 = parser.segments[1]
        # pos=2670611717, start=2619460869 (segment 0's limit)
        expect(seg1.downloaded).to eq(51_150_848)
      end

      it "calculates segment percentages" do
        seg0 = parser.segments[0]
        # 57442304 / 2619460869 = 2.19%
        expect(seg0.percent).to be_within(0.1).of(2.2)
      end

      it "calculates overall percent" do
        result = parser.to_h
        expect(result[:overall_percent]).to be_within(0.5).of(2.1)
      end

      it "calculates total downloaded" do
        result = parser.to_h
        expect(result[:total_downloaded]).to be > 400_000_000 # ~450MB
      end

      it "has segments with correct structure" do
        seg = parser.segments.first
        expect(seg.index).to eq(0)
        expect(seg.pos).to eq(57_442_304)
        expect(seg.limit).to eq(2_619_460_869)
        expect(seg.start).to eq(0)
      end
    end

    context "with size=-2 (error state)" do
      let(:content) { "size=-2\n0.pos=545193984\n0.limit=1000000000\n" }

      before { parser.parse_content(content) }

      it "parses negative size" do
        expect(parser.total_size).to eq(-2)
      end

      it "returns 0 for overall percent when size is invalid" do
        expect(parser.to_h[:overall_percent]).to eq(0.0)
      end
    end

    context "with single segment" do
      let(:content) do
        <<~STATUS
          size=1000000
          0.pos=500000
          0.limit=1000000
        STATUS
      end

      before { parser.parse_content(content) }

      it "parses single segment" do
        expect(parser.segments.size).to eq(1)
      end

      it "calculates 50% progress" do
        expect(parser.segments[0].percent).to eq(50.0)
      end

      it "calculates overall 50% progress" do
        expect(parser.overall_percent).to eq(50.0)
      end
    end

    context "with empty content" do
      before { parser.parse_content("") }

      it "has nil total_size" do
        expect(parser.total_size).to be_nil
      end

      it "has empty segments" do
        expect(parser.segments).to eq([])
      end

      it "returns 0 for total_downloaded" do
        expect(parser.total_downloaded).to eq(0)
      end

      it "returns 0 for overall_percent" do
        expect(parser.overall_percent).to eq(0.0)
      end
    end

    context "with incomplete segment data" do
      let(:content) do
        <<~STATUS
          size=1000000
          0.pos=500000
        STATUS
      end

      before { parser.parse_content(content) }

      it "skips segments without both pos and limit" do
        expect(parser.segments).to eq([])
      end
    end
  end

  describe "#parse" do
    it "returns false when file does not exist" do
      expect(parser.parse("/nonexistent/path/file.lftp-pget-status")).to be false
    end

    it "returns true and parses when file exists" do
      Tempfile.create("status") do |f|
        f.write("size=1000\n0.pos=500\n0.limit=1000\n")
        f.rewind
        expect(parser.parse(f.path)).to be true
        expect(parser.total_size).to eq(1000)
      end
    end
  end

  describe "#to_h" do
    let(:content) { "size=1000\n0.pos=250\n0.limit=1000\n" }

    before { parser.parse_content(content) }

    it "returns hash with all expected keys" do
      result = parser.to_h
      expect(result).to include(
        :total_size,
        :segments,
        :total_downloaded,
        :overall_percent
      )
    end

    it "has correct total_size" do
      expect(parser.to_h[:total_size]).to eq(1000)
    end

    it "has correct total_downloaded" do
      expect(parser.to_h[:total_downloaded]).to eq(250)
    end

    it "has correct overall_percent" do
      expect(parser.to_h[:overall_percent]).to eq(25.0)
    end

    it "includes segment hashes with expected keys" do
      seg = parser.to_h[:segments].first
      expect(seg).to include(
        :index, :pos, :limit, :start,
        :downloaded, :segment_size, :percent
      )
    end

    it "includes correct segment values" do
      seg = parser.to_h[:segments].first
      expect(seg[:index]).to eq(0)
      expect(seg[:pos]).to eq(250)
      expect(seg[:limit]).to eq(1000)
      expect(seg[:start]).to eq(0)
      expect(seg[:downloaded]).to eq(250)
      expect(seg[:segment_size]).to eq(1000)
      expect(seg[:percent]).to eq(25.0)
    end
  end

  describe "Segment struct" do
    let(:segment) do
      described_class::Segment.new(
        index: 0,
        pos: 300,
        limit: 1000,
        start: 0
      )
    end

    describe "#downloaded" do
      it "calculates bytes downloaded as pos - start" do
        expect(segment.downloaded).to eq(300)
      end
    end

    describe "#segment_size" do
      it "calculates segment size as limit - start" do
        expect(segment.segment_size).to eq(1000)
      end
    end

    describe "#percent" do
      it "calculates percent complete" do
        expect(segment.percent).to eq(30.0)
      end

      it "returns 0 for zero-size segment" do
        zero_segment = described_class::Segment.new(
          index: 0, pos: 0, limit: 0, start: 0
        )
        expect(zero_segment.percent).to eq(0.0)
      end
    end
  end
end
