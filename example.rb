#!/usr/bin/env ruby
# frozen_string_literal: true

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
