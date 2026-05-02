# frozen_string_literal: true

require_relative "lib/speech_mac/version"

Gem::Specification.new do |spec|
  spec.name = "rb-speech-mac"
  spec.version = SpeechMac::VERSION
  spec.authors = ["bash0C7"]
  spec.email = ["ksb.4038.nullpointer+github@gmail.com"]

  spec.summary = "Ruby binding for Apple Speech framework on macOS"
  spec.description = "Calls Apple Speech framework's file-based speech recognition (SFSpeechURLRecognitionRequest) from Ruby on macOS / Apple Silicon, via a TCC-permitted helper subprocess built and signed at install time."
  spec.homepage = "https://github.com/bash0C7/rb-speech-mac"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bash0C7/rb-speech-mac"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .github/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.extensions = ["ext/speech_mac/extconf.rb"]
end
