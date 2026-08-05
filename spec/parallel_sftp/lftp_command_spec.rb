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

    it "includes secure TLS and host-key defaults" do
      script = command.to_script

      expect(script).to include("set sftp:auto-confirm no")
      expect(script).to include("set ssl:verify-certificate yes")
      expect(script).not_to include("set sftp:auto-confirm yes")
      expect(script).not_to include("set ssl:verify-certificate no")
    end

    context "with insecure: true" do
      let(:command) { described_class.new(options.merge(insecure: true)) }

      it "restores legacy auto-confirm and disabled cert verify" do
        script = command.to_script
        expect(script).to include("set sftp:auto-confirm yes")
        expect(script).to include("set ssl:verify-certificate no")
      end
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

    context "without sftp_connect_program" do
      it "does not include connect-program setting" do
        expect(command.to_script).not_to include("sftp:connect-program")
      end
    end

    context "with sftp_connect_program option" do
      let(:ssh_opts) { "ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa" }
      let(:command) { described_class.new(options.merge(sftp_connect_program: ssh_opts)) }

      it "includes the connect-program setting" do
        expect(command.to_script).to include("set sftp:connect-program \"#{ssh_opts}\"")
      end

      it "places connect-program before the open command" do
        script = command.to_script
        connect_program_pos = script.index("sftp:connect-program")
        open_pos = script.index("open -p")
        expect(connect_program_pos).to be < open_pos
      end
    end

    context "with global sftp_connect_program configuration" do
      let(:ssh_opts) { "ssh -o HostKeyAlgorithms=+ssh-rsa" }

      before do
        ParallelSftp.configure do |config|
          config.sftp_connect_program = ssh_opts
        end
      end

      after { ParallelSftp.reset_configuration! }

      it "uses global config when not specified per-call" do
        expect(command.to_script).to include("HostKeyAlgorithms=+ssh-rsa")
      end

      it "allows per-call override" do
        custom_ssh = "ssh -o StrictHostKeyChecking=no"
        custom_command = described_class.new(options.merge(sftp_connect_program: custom_ssh))
        expect(custom_command.to_script).to include("StrictHostKeyChecking=no")
        expect(custom_command.to_script).not_to include("HostKeyAlgorithms")
      end
    end
  end

  describe "#to_command" do
    it "returns a legacy array for Open3 (password still on argv — prefer with_script_file)" do
      cmd = command.to_command

      expect(cmd).to be_an(Array)
      expect(cmd.first).to eq("lftp")
      expect(cmd[1]).to eq("-c")
      expect(cmd[2]).to be_a(String)
    end
  end

  describe "#to_argv" do
    it "uses -f with a script path and never embeds the password" do
      argv = command.to_argv("/tmp/script.lftp")
      expect(argv).to eq(["lftp", "-f", "/tmp/script.lftp"])
      expect(argv.join(" ")).not_to include("secret123")
    end
  end

  describe "#with_script_file" do
    it "writes a 0600 script, yields the path, and unlinks afterward" do
      path_seen = nil
      mode_seen = nil
      content_seen = nil

      command.with_script_file do |path|
        path_seen = path
        expect(File.exist?(path)).to be(true)
        mode_seen = File.stat(path).mode & 0o777
        content_seen = File.read(path)
      end

      expect(mode_seen).to eq(0o600)
      expect(content_seen).to include("open -p")
      expect(content_seen).to include("secret123")
      expect(File.exist?(path_seen)).to be(false)
    end

    it "unlinks the tempfile even when the block raises" do
      path_seen = nil
      expect do
        command.with_script_file do |path|
          path_seen = path
          raise "boom"
        end
      end.to raise_error("boom")
      expect(File.exist?(path_seen)).to be(false)
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

  describe "injection hardening" do
    it "rejects remote_path that breaks out of double quotes" do
      expect do
        described_class.new(options.merge(remote_path: %q{/a"; !echo pwned; "}))
      end.to raise_error(ArgumentError, /remote_path/)
    end

    it "rejects local_path with backticks" do
      expect do
        described_class.new(options.merge(local_path: "/tmp/`id`"))
      end.to raise_error(ArgumentError, /local_path/)
    end

    it "allows spaces in paths" do
      cmd = described_class.new(options.merge(
        remote_path: "/data/my file.zip",
        local_path: "/tmp/my file.zip"
      ))
      expect(cmd.to_script).to include('"/data/my file.zip"')
    end

    it "rejects sftp_connect_program quote breakout" do
      expect do
        described_class.new(options.merge(sftp_connect_program: %q{ssh -o "foo; touch /tmp/pwned}))
      end.to raise_error(ArgumentError, /sftp_connect_program/)
    end

    it "rejects non-ssh connect programs" do
      expect do
        described_class.new(options.merge(sftp_connect_program: "bash -c evil"))
      end.to raise_error(ArgumentError, /sftp_connect_program/)
    end

    it "rejects ProxyCommand in sftp_connect_program" do
      expect do
        described_class.new(options.merge(
          sftp_connect_program: "ssh -o ProxyCommand=ncat,--exec,/bin/sh"
        ))
      end.to raise_error(ArgumentError, /sftp_connect_program/)
    end

    it "rejects LocalCommand in sftp_connect_program" do
      expect do
        described_class.new(options.merge(
          sftp_connect_program: "ssh -o PermitLocalCommand=yes -o LocalCommand=id"
        ))
      end.to raise_error(ArgumentError, /sftp_connect_program/)
    end

    it "rejects KnownHostsCommand in sftp_connect_program" do
      expect do
        described_class.new(options.merge(
          sftp_connect_program: "ssh -o KnownHostsCommand=/bin/true"
        ))
      end.to raise_error(ArgumentError, /sftp_connect_program/)
    end

    it "allows documented host-key algorithm connect-program" do
      prog = "ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa"
      cmd = described_class.new(options.merge(sftp_connect_program: prog))
      expect(cmd.to_script).to include(prog)
    end

    it "URL-encodes special characters in user" do
      cmd = described_class.new(options.merge(user: "user+name"))
      expect(cmd.to_script).to include("sftp://user%2Bname:")
    end

    it "rejects invalid host" do
      expect do
        described_class.new(options.merge(host: "evil host;pwn"))
      end.to raise_error(ArgumentError, /host/)
    end

    it "rejects non-integer-looking segments via Integer()" do
      expect do
        described_class.new(options.merge(segments: "4; !x"))
      end.to raise_error(ArgumentError)
    end
  end
end

