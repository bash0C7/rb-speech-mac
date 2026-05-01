# frozen_string_literal: true

require "test_helper"

class SpeechMacTest < Test::Unit::TestCase
  FIXTURE = File.expand_path("../fixtures/sample.aiff", __dir__)

  test "transcribe returns a String for a valid audio file" do
    output = SpeechMac.transcribe(FIXTURE)
    assert_kind_of(String, output)
  end

  test "transcribe returns empty string for nonexistent path" do
    assert_equal("", SpeechMac.transcribe("/nonexistent/path/missing.aiff"))
  end

  test "transcribe returns empty string for empty path argument" do
    assert_equal("", SpeechMac.transcribe(""))
  end
end
