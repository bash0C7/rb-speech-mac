# frozen_string_literal: true

require "test_helper"

class SpeechMacAuthorizeTest < Test::Unit::TestCase
  FAKE_HELPER = File.expand_path("../fixtures/fake_helper.sh", __dir__)

  def setup
    @original_helper_path = SpeechMac.helper_path
    SpeechMac.helper_path = FAKE_HELPER
    %w[FAKE_EXIT FAKE_STDOUT FAKE_STDERR].each { |k| ENV.delete(k) }
  end

  def teardown
    SpeechMac.helper_path = @original_helper_path
    %w[FAKE_EXIT FAKE_STDOUT FAKE_STDERR].each { |k| ENV.delete(k) }
  end

  test "authorize returns an AuthorizationResult" do
    ENV["FAKE_EXIT"] = "0"
    ENV["FAKE_STDOUT"] = "authorized"
    result = SpeechMac.authorize
    assert_kind_of(SpeechMac::AuthorizationResult, result)
  end

  test "authorize success: status :authorized, success true, no error" do
    ENV["FAKE_EXIT"] = "0"
    ENV["FAKE_STDOUT"] = "authorized"
    result = SpeechMac.authorize
    assert_equal(:authorized, result.status)
    assert_equal(true, result.success)
    assert_nil(result.error)
  end

  test "authorize denied: status :denied, NotAuthorizedError" do
    ENV["FAKE_EXIT"] = "2"
    ENV["FAKE_STDOUT"] = "denied"
    result = SpeechMac.authorize
    assert_equal(:denied, result.status)
    assert_equal(false, result.success)
    assert_kind_of(SpeechMac::NotAuthorizedError, result.error)
  end

  test "authorize with helper missing -> HelperSpawnError" do
    SpeechMac.helper_path = "/nonexistent/__missing"
    result = SpeechMac.authorize
    assert_equal(false, result.success)
    assert_kind_of(SpeechMac::HelperSpawnError, result.error)
  end
end
