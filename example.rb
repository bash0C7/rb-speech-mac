#!/usr/bin/env ruby
# frozen_string_literal: true

# Run with: bundle exec ruby example.rb [<audio-path>]
# Build the native extension first: bundle exec rake compile
#
# Note: from a CLI Ruby host without NSSpeechRecognitionUsageDescription in
# its Info.plist, transcribe will return "" (see CLAUDE.md "Known limitations").

require_relative "lib/speech_mac"

path = ARGV.first || File.expand_path("test/fixtures/sample.aiff", __dir__)

puts "audio: #{path}"
result = SpeechMac.transcribe(path)
if result.empty?
  puts "(empty — speech recognition not authorized for this host process; see CLAUDE.md)"
else
  puts result
end
