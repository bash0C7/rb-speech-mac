# frozen_string_literal: true

require "test_helper"

class SpeechMacTranscribeTest < Test::Unit::TestCase
  include FakeHelperSupport

  FIXTURE = File.expand_path("../fixtures/sample.aiff", __dir__)

  test "helper_path is configurable" do
    SpeechMac.helper_path = "/some/custom/path"
    assert_equal("/some/custom/path", SpeechMac.helper_path)
  end

  test "transcribe returns a Result" do
    ENV["FAKE_EXIT"] = "0"
    ENV["FAKE_STDOUT"] = "hello"
    result = SpeechMac.transcribe(FIXTURE)
    assert_kind_of(SpeechMac::Result, result)
  end

  test "transcribe success: text from helper stdout" do
    ENV["FAKE_EXIT"] = "0"
    ENV["FAKE_STDOUT"] = "hello world"
    result = SpeechMac.transcribe(FIXTURE)
    assert_equal(true, result.success)
    assert_equal("hello world", result.text)
    assert_nil(result.error)
  end

  test "transcribe failure: helper exit 4 -> FileNotFoundError" do
    ENV["FAKE_EXIT"] = "4"
    result = SpeechMac.transcribe("/nonexistent/missing.aiff")
    assert_equal(false, result.success)
    assert_nil(result.text)
    assert_kind_of(SpeechMac::FileNotFoundError, result.error)
  end

  test "transcribe with helper binary missing -> HelperSpawnError" do
    SpeechMac.helper_path = "/nonexistent/__missing_helper"
    result = SpeechMac.transcribe(FIXTURE)
    assert_equal(false, result.success)
    assert_kind_of(SpeechMac::HelperSpawnError, result.error)
  end
end
