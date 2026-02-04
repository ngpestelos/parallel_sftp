# frozen_string_literal: true

require "spec_helper"

RSpec.describe ParallelSftp::Configuration do
  subject(:config) { described_class.new }

  describe "default values" do
    it "has default_segments of 4" do
      expect(config.default_segments).to eq(4)
    end

    it "has timeout of 30 seconds" do
      expect(config.timeout).to eq(30)
    end

    it "has max_retries of 10" do
      expect(config.max_retries).to eq(10)
    end

    it "has reconnect_interval of 5 seconds" do
      expect(config.reconnect_interval).to eq(5)
    end

    it "has default_port of 22" do
      expect(config.default_port).to eq(22)
    end
  end

  describe "attribute accessors" do
    it "allows setting default_segments" do
      config.default_segments = 8
      expect(config.default_segments).to eq(8)
    end

    it "allows setting timeout" do
      config.timeout = 120
      expect(config.timeout).to eq(120)
    end

    it "allows setting max_retries" do
      config.max_retries = 20
      expect(config.max_retries).to eq(20)
    end

    it "allows setting reconnect_interval" do
      config.reconnect_interval = 15
      expect(config.reconnect_interval).to eq(15)
    end

    it "allows setting default_port" do
      config.default_port = 2222
      expect(config.default_port).to eq(2222)
    end
  end

  describe "#optimize_for_large_files!" do
    before { config.optimize_for_large_files! }

    it "sets default_segments to 8" do
      expect(config.default_segments).to eq(8)
    end

    it "sets timeout to 60 seconds" do
      expect(config.timeout).to eq(60)
    end

    it "sets max_retries to 15" do
      expect(config.max_retries).to eq(15)
    end

    it "sets reconnect_interval to 10 seconds" do
      expect(config.reconnect_interval).to eq(10)
    end
  end
end
