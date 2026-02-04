# frozen_string_literal: true

require "spec_helper"

RSpec.describe ParallelSftp::TimeEstimator do
  subject(:estimator) { described_class.new(window_size: 5) }

  describe "#initialize" do
    it "sets the window size" do
      expect(estimator.window_size).to eq(5)
    end

    it "defaults to window size of 10" do
      default_estimator = described_class.new
      expect(default_estimator.window_size).to eq(10)
    end
  end

  describe "#record" do
    it "stores samples without error" do
      expect { estimator.record(1000, Time.now) }.not_to raise_error
    end

    it "limits samples to window size" do
      t = Time.now
      6.times { |i| estimator.record(i * 1000, t + i) }
      # Should have dropped first sample, speed should be 1000 bytes/sec
      expect(estimator.speed_bytes_per_second).to eq(1000)
    end
  end

  describe "#speed_bytes_per_second" do
    it "returns nil with no samples" do
      expect(estimator.speed_bytes_per_second).to be_nil
    end

    it "returns nil with only one sample" do
      estimator.record(1000, Time.now)
      expect(estimator.speed_bytes_per_second).to be_nil
    end

    it "calculates correct speed" do
      t = Time.now
      estimator.record(0, t)
      estimator.record(10_000_000, t + 10) # 10MB in 10 seconds
      expect(estimator.speed_bytes_per_second).to eq(1_000_000) # 1MB/s
    end

    it "uses window for recent speed" do
      t = Time.now
      estimator.record(0, t)
      estimator.record(1_000_000, t + 10)  # slow start
      estimator.record(11_000_000, t + 15) # speed up
      estimator.record(21_000_000, t + 20) # sustained
      # Window sees 0->21MB in 20s = ~1MB/s average
      expect(estimator.speed_bytes_per_second).to be_within(100_000).of(1_050_000)
    end

    it "returns nil when time delta is zero" do
      t = Time.now
      estimator.record(0, t)
      estimator.record(1000, t) # Same timestamp
      expect(estimator.speed_bytes_per_second).to be_nil
    end
  end

  describe "#eta_seconds" do
    before do
      t = Time.now
      estimator.record(0, t)
      estimator.record(1_000_000, t + 1) # 1MB/s
    end

    it "calculates remaining time" do
      # 1MB/s, 9MB remaining = 9 seconds
      expect(estimator.eta_seconds(10_000_000, 1_000_000)).to eq(9)
    end

    it "returns 0 when download complete" do
      expect(estimator.eta_seconds(1_000_000, 1_000_000)).to eq(0)
    end

    it "returns 0 when current exceeds total" do
      expect(estimator.eta_seconds(1_000_000, 2_000_000)).to eq(0)
    end

    it "returns nil when no speed data" do
      fresh = described_class.new
      expect(fresh.eta_seconds(1000, 500)).to be_nil
    end

    it "returns nil when speed is zero" do
      # Record same bytes to get zero speed
      t = Time.now
      slow = described_class.new
      slow.record(1000, t)
      slow.record(1000, t + 1)
      expect(slow.eta_seconds(2000, 1000)).to be_nil
    end
  end

  describe "#eta_formatted" do
    before do
      t = Time.now
      estimator.record(0, t)
      estimator.record(1_000_000, t + 1) # 1MB/s
    end

    it "formats seconds" do
      # 45 bytes remaining at 1MB/s rounds to 0s
      expect(estimator.eta_formatted(1_000_045, 1_000_000)).to eq("0s")
    end

    it "formats seconds correctly" do
      # 45_000_000 bytes remaining at 1MB/s = 45s
      expect(estimator.eta_formatted(1_000_000 + 45_000_000, 1_000_000)).to eq("45s")
    end

    it "formats minutes and seconds" do
      # 90_000_000 bytes remaining at 1MB/s = 90s = 1m30s
      expect(estimator.eta_formatted(1_000_000 + 90_000_000, 1_000_000)).to eq("1m30s")
    end

    it "formats hours and minutes" do
      # 3700_000_000 bytes remaining at 1MB/s = 3700s = 1h1m
      expect(estimator.eta_formatted(1_000_000 + 3_700_000_000, 1_000_000)).to eq("1h1m")
    end

    it "returns nil when no speed data" do
      fresh = described_class.new
      expect(fresh.eta_formatted(1000, 500)).to be_nil
    end
  end

  describe "#elapsed_seconds" do
    it "returns 0 before any samples" do
      expect(estimator.elapsed_seconds).to eq(0)
    end

    it "returns elapsed time since first sample" do
      estimator.record(100, Time.now - 10)
      expect(estimator.elapsed_seconds).to be_within(1).of(10)
    end

    it "tracks from first sample even after multiple records" do
      t = Time.now
      estimator.record(0, t - 20)
      estimator.record(1000, t - 10)
      estimator.record(2000, t)
      expect(estimator.elapsed_seconds).to be_within(1).of(20)
    end
  end

  describe "#average_speed" do
    it "returns nil before any samples" do
      expect(estimator.average_speed).to be_nil
    end

    it "calculates average from start" do
      t = Time.now
      estimator.record(0, t - 10)
      estimator.record(10_000_000, t) # 10MB in 10s
      expect(estimator.average_speed).to be_within(10_000).of(1_000_000)
    end
  end

  describe "#reset!" do
    before do
      t = Time.now
      estimator.record(0, t)
      estimator.record(1_000_000, t + 1)
    end

    it "clears all samples" do
      estimator.reset!
      expect(estimator.speed_bytes_per_second).to be_nil
    end

    it "resets elapsed time" do
      estimator.reset!
      expect(estimator.elapsed_seconds).to eq(0)
    end

    it "resets average speed" do
      estimator.reset!
      expect(estimator.average_speed).to be_nil
    end
  end

  describe "format_duration (private)" do
    it "handles zero seconds" do
      t = Time.now
      estimator.record(0, t)
      estimator.record(1_000_000, t + 1) # 1MB/s
      # When we're already at the total, we get 0
      expect(estimator.eta_formatted(1_000_000, 1_000_000)).to eq("0s")
    end
  end
end
