# frozen_string_literal: true

require "bundler/setup"
require "parallel_sftp"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    ParallelSftp.reset_configuration!
  end
end
