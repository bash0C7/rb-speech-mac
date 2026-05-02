# frozen_string_literal: true

require "test_helper"

class SpeechMacErrorsTest < Test::Unit::TestCase
  test "Error inherits from StandardError" do
    assert_operator(SpeechMac::Error, :<, StandardError)
  end

  test "NotAuthorizedError inherits from SpeechMac::Error" do
    assert_operator(SpeechMac::NotAuthorizedError, :<, SpeechMac::Error)
  end

  test "TimeoutError inherits from SpeechMac::Error" do
    assert_operator(SpeechMac::TimeoutError, :<, SpeechMac::Error)
  end

  test "HelperSpawnError inherits from SpeechMac::Error" do
    assert_operator(SpeechMac::HelperSpawnError, :<, SpeechMac::Error)
  end

  test "FileNotFoundError inherits from SpeechMac::Error" do
    assert_operator(SpeechMac::FileNotFoundError, :<, SpeechMac::Error)
  end

  test "RecognizerUnavailableError inherits from SpeechMac::Error" do
    assert_operator(SpeechMac::RecognizerUnavailableError, :<, SpeechMac::Error)
  end

  test "HelperCrashError inherits from SpeechMac::Error" do
    assert_operator(SpeechMac::HelperCrashError, :<, SpeechMac::Error)
  end
end

class SpeechMacResultTest < Test::Unit::TestCase
  test "Result is a Data class with text, success, error members" do
    result = SpeechMac::Result.new(text: "hello", success: true, error: nil)
    assert_kind_of(Data, result)
    assert_equal("hello", result.text)
    assert_equal(true, result.success)
    assert_nil(result.error)
  end

  test "Result on failure carries nil text and error instance" do
    err = SpeechMac::TimeoutError.new("30s exceeded")
    result = SpeechMac::Result.new(text: nil, success: false, error: err)
    assert_nil(result.text)
    assert_equal(false, result.success)
    assert_same(err, result.error)
  end

  test "Result is immutable (frozen Data)" do
    result = SpeechMac::Result.new(text: "x", success: true, error: nil)
    assert_raise(FrozenError) { result.instance_variable_set(:@foo, 1) }
  end
end

class SpeechMacAuthorizationResultTest < Test::Unit::TestCase
  test "AuthorizationResult is a Data class with status, success, error members" do
    auth = SpeechMac::AuthorizationResult.new(status: :authorized, success: true, error: nil)
    assert_kind_of(Data, auth)
    assert_equal(:authorized, auth.status)
    assert_equal(true, auth.success)
    assert_nil(auth.error)
  end

  test "AuthorizationResult on failure carries error instance" do
    err = SpeechMac::NotAuthorizedError.new("denied")
    auth = SpeechMac::AuthorizationResult.new(status: :denied, success: false, error: err)
    assert_equal(:denied, auth.status)
    assert_equal(false, auth.success)
    assert_same(err, auth.error)
  end
end
