#!/usr/bin/env ruby
# frozen_string_literal: true

# Run with: bundle exec ruby example.rb [<audio-path>]
# Build the helper first: bundle exec rake compile
#
# First run on a machine triggers the macOS Speech Recognition permission
# dialog. Re-running after a rebuild re-prompts if you signed ad-hoc — to
# avoid that, use an Apple Development cert (set SPEECH_MAC_CODESIGN_IDENTITY).

require_relative "lib/speech_mac"

path = ARGV.first || File.expand_path("test/fixtures/sample.aiff", __dir__)

auth = SpeechMac.authorize
puts "authorize: status=#{auth.status} success=#{auth.success}"
unless auth.success
  warn "  #{auth.error.class}: #{auth.error.message}"
  exit 1
end

puts "audio: #{path}"
result = SpeechMac.transcribe(path)
if result.success
  puts result.text
else
  warn "transcribe failed: #{result.error.class}: #{result.error.message}"
  exit 1
end
