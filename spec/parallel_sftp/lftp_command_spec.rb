# frozen_string_literal: true

require "spec_helper"

RSpec.describe ParallelSftp::LftpCommand do
  let(:options) do
    {
      host: "sftp.example.com",
      user: "testuser",
      password: "secret123",
      port: 22,
      remote_path: "/data/large_file.zip",
      local_path: "/tmp/large_file.zip"
    }
  end

  subject(:command) { described_class.new(options) }

  describe "#initialize" do
    it "stores connection details" do
      expect(command.host).to eq("sftp.example.com")
      expect(command.user).to eq("testuser")
      expect(command.password).to eq("secret123")
      expect(command.port).to eq(22)
    end

    it "stores file paths" do
      expect(command.remote_path).to eq("/data/large_file.zip")
      expect(command.local_path).to eq("/tmp/large_file.zip")
    end

    it "uses default values from configuration" do
      expect(command.segments).to eq(4)
      expect(command.timeout).to eq(30)
      expect(command.max_retries).to eq(10)
      expect(command.reconnect_interval).to eq(5)
    end

    it "allows overriding defaults" do
      custom_command = described_class.new(options.merge(
        segments: 8,
        timeout: 60,
        max_retries: 15,
        reconnect_interval: 10
      ))

      expect(custom_command.segments).to eq(8)
      expect(custom_command.timeout).to eq(60)
      expect(custom_command.max_retries).to eq(15)
      expect(custom_command.reconnect_interval).to eq(10)
    end
  end

  describe "#to_script" do
    it "includes network settings" do
      script = command.to_script

      expect(script).to include("set net:timeout 30")
      expect(script).to include("set net:max-retries 10")
      expect(script).to include("set net:reconnect-interval-base 5")
    end

    it "includes SFTP settings" do
      script = command.to_script

      expect(script).to include("set sftp:auto-confirm yes")
      expect(script).to include("set ssl:verify-certificate no")
    end

    it "includes the open command with credentials" do
      script = command.to_script

      expect(script).to include("open -p 22 sftp://testuser:secret123@sftp.example.com")
    end

    it "includes the pget command with segments and resume" do
      script = command.to_script

      expect(script).to include('pget -n 4 -c "/data/large_file.zip" -o "/tmp/large_file.zip"')
    end

    it "includes quit command" do
      expect(command.to_script).to include("quit")
    end

    context "with resume disabled" do
      let(:command) { described_class.new(options.merge(resume: false)) }

      it "omits the -c flag" do
        script = command.to_script

        expect(script).to include('pget -n 4 "/data/large_file.zip"')
        expect(script).not_to include("pget -n 4 -c")
      end
    end

    context "with custom segments" do
      let(:command) { described_class.new(options.merge(segments: 8)) }

      it "uses the custom segment count" do
        expect(command.to_script).to include("pget -n 8")
      end
    end
  end

  describe "#to_command" do
    it "returns an array for Open3" do
      cmd = command.to_command

      expect(cmd).to be_an(Array)
      expect(cmd.first).to eq("lftp")
      expect(cmd[1]).to eq("-c")
      expect(cmd[2]).to be_a(String)
    end
  end

  describe "password escaping" do
    context "with special characters in password" do
      let(:command) do
        described_class.new(options.merge(password: "p@ss:word/test!"))
      end

      it "URL-encodes special characters" do
        script = command.to_script

        expect(script).to include("p%40ss%3Aword%2Ftest%21")
        expect(script).not_to include("p@ss:word/test!")
      end
    end

    context "with alphanumeric password" do
      let(:command) do
        described_class.new(options.merge(password: "SimplePassword123"))
      end

      it "leaves the password unchanged" do
        expect(command.to_script).to include("SimplePassword123")
      end
    end
  end
end
