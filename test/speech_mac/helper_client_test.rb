# frozen_string_literal: true

require "test_helper"

class HelperClientTest < Test::Unit::TestCase
  FAKE_HELPER = File.expand_path("../fixtures/fake_helper.sh", __dir__)

  def setup
    %w[FAKE_EXIT FAKE_STDOUT FAKE_STDERR FAKE_SIGNAL].each { |k| ENV.delete(k) }
  end

  def teardown
    %w[FAKE_EXIT FAKE_STDOUT FAKE_STDERR FAKE_SIGNAL].each { |k| ENV.delete(k) }
  end

  def build_client(exit_code: 0, stdout: "", stderr: "", path: FAKE_HELPER)
    ENV["FAKE_EXIT"] = exit_code.to_s
    ENV["FAKE_STDOUT"] = stdout
    ENV["FAKE_STDERR"] = stderr
    SpeechMac::HelperClient.new(path)
  end

  # transcribe
  test "transcribe success: exit 0 -> Result(success: true, text: stdout)" do
    client = build_client(exit_code: 0, stdout: "hello world")
    result = client.transcribe("/some/path")
    assert_kind_of(SpeechMac::Result, result)
    assert_equal(true, result.success)
    assert_equal("hello world", result.text)
    assert_nil(result.error)
  end

  test "transcribe exit 2 -> NotAuthorizedError" do
    client = build_client(exit_code: 2)
    result = client.transcribe("/some/path")
    assert_equal(false, result.success)
    assert_nil(result.text)
    assert_kind_of(SpeechMac::NotAuthorizedError, result.error)
  end

  test "transcribe exit 3 -> RecognizerUnavailableError" do
    client = build_client(exit_code: 3)
    result = client.transcribe("/some/path")
    assert_kind_of(SpeechMac::RecognizerUnavailableError, result.error)
  end

  test "transcribe exit 4 -> FileNotFoundError" do
    client = build_client(exit_code: 4)
    result = client.transcribe("/some/path")
    assert_kind_of(SpeechMac::FileNotFoundError, result.error)
  end

  test "transcribe exit 5 -> TimeoutError" do
    client = build_client(exit_code: 5)
    result = client.transcribe("/some/path")
    assert_kind_of(SpeechMac::TimeoutError, result.error)
  end

  test "transcribe exit 6 -> generic Error with stderr in message" do
    client = build_client(exit_code: 6, stderr: "recognition failed: foo")
    result = client.transcribe("/some/path")
    assert_kind_of(SpeechMac::Error, result.error)
    assert_not_kind_of(SpeechMac::HelperCrashError, result.error)
    assert_match(/recognition failed: foo/, result.error.message)
  end

  test "transcribe unknown non-zero exit -> HelperCrashError" do
    client = build_client(exit_code: 99, stderr: "segfault")
    result = client.transcribe("/some/path")
    assert_kind_of(SpeechMac::HelperCrashError, result.error)
  end

  test "transcribe with missing helper binary -> HelperSpawnError" do
    client = SpeechMac::HelperClient.new("/nonexistent/__missing_helper_xyz")
    result = client.transcribe("/some/path")
    assert_kind_of(SpeechMac::HelperSpawnError, result.error)
    assert_nil(result.text)
    assert_equal(false, result.success)
  end

  test "transcribe with helper killed by signal -> HelperCrashError" do
    ENV["FAKE_SIGNAL"] = "KILL"
    client = SpeechMac::HelperClient.new(FAKE_HELPER)
    result = client.transcribe("/some/path")
    assert_kind_of(SpeechMac::HelperCrashError, result.error)
    assert_equal(false, result.success)
    assert_nil(result.text)
  end

  test "authorize with helper killed by signal -> HelperCrashError" do
    ENV["FAKE_SIGNAL"] = "KILL"
    client = SpeechMac::HelperClient.new(FAKE_HELPER)
    result = client.authorize
    assert_kind_of(SpeechMac::AuthorizationResult, result)
    assert_equal(false, result.success)
    assert_kind_of(SpeechMac::HelperCrashError, result.error)
  end

  # authorize
  test "authorize exit 0 stdout=authorized -> AuthorizationResult(:authorized, success: true)" do
    client = build_client(exit_code: 0, stdout: "authorized")
    result = client.authorize
    assert_kind_of(SpeechMac::AuthorizationResult, result)
    assert_equal(:authorized, result.status)
    assert_equal(true, result.success)
    assert_nil(result.error)
  end

  test "authorize exit 2 stdout=denied -> AuthorizationResult(:denied, NotAuthorizedError)" do
    client = build_client(exit_code: 2, stdout: "denied")
    result = client.authorize
    assert_equal(:denied, result.status)
    assert_equal(false, result.success)
    assert_kind_of(SpeechMac::NotAuthorizedError, result.error)
  end

  test "authorize exit 2 stdout=restricted -> :restricted" do
    client = build_client(exit_code: 2, stdout: "restricted")
    result = client.authorize
    assert_equal(:restricted, result.status)
    assert_kind_of(SpeechMac::NotAuthorizedError, result.error)
  end

  test "authorize exit 2 stdout=notDetermined -> :not_determined" do
    client = build_client(exit_code: 2, stdout: "notDetermined")
    result = client.authorize
    assert_equal(:not_determined, result.status)
    assert_kind_of(SpeechMac::NotAuthorizedError, result.error)
  end

  test "authorize with missing helper binary -> AuthorizationResult with HelperSpawnError" do
    client = SpeechMac::HelperClient.new("/nonexistent/__missing_helper_xyz")
    result = client.authorize
    assert_kind_of(SpeechMac::AuthorizationResult, result)
    assert_equal(false, result.success)
    assert_kind_of(SpeechMac::HelperSpawnError, result.error)
  end
end
