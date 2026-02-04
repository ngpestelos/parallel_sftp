# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "parallel_sftp/version"

Gem::Specification.new do |spec|
  spec.name          = "parallel_sftp"
  spec.version       = ParallelSftp::VERSION
  spec.authors       = ["Nestor G Pestelos Jr"]
  spec.email         = ["ngpestelos@gmail.com"]

  spec.summary       = "Fast parallel SFTP downloads using lftp's segmented transfer"
  spec.description   = "A Ruby gem that wraps lftp for parallel/segmented SFTP downloads of large files. " \
                       "Supports resume, progress callbacks, and configurable retry settings."
  spec.homepage      = "https://github.com/ngpestelos/parallel_sftp"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 2.5.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/master/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", ">= 1.17"
  spec.add_development_dependency "rake", ">= 12.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
