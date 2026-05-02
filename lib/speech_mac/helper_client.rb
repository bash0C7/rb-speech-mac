# frozen_string_literal: true

require "open3"

module SpeechMac
  class HelperClient
    EXIT_CODE_ERRORS = {
      2 => NotAuthorizedError,
      3 => RecognizerUnavailableError,
      4 => FileNotFoundError,
      5 => TimeoutError,
    }.freeze

    AUTHORIZATION_STATUSES = {
      "authorized" => :authorized,
      "denied" => :denied,
      "restricted" => :restricted,
      "notDetermined" => :not_determined,
    }.freeze

    def initialize(helper_path)
      @helper_path = helper_path
    end

    def transcribe(audio_path)
      stdout, stderr, status = run("transcribe", audio_path)
      if status.exitstatus.zero?
        Result.new(text: stdout, success: true, error: nil)
      else
        Result.new(text: nil, success: false, error: error_for(status.exitstatus, stderr))
      end
    rescue Errno::ENOENT, Errno::EACCES => e
      Result.new(text: nil, success: false, error: HelperSpawnError.new(e.message))
    end

    def authorize
      stdout, stderr, status = run("authorize")
      sym = AUTHORIZATION_STATUSES.fetch(stdout.strip, :unknown)
      if status.exitstatus.zero?
        AuthorizationResult.new(status: sym, success: true, error: nil)
      else
        message = stderr.empty? ? stdout : stderr
        AuthorizationResult.new(status: sym, success: false, error: NotAuthorizedError.new(message))
      end
    rescue Errno::ENOENT, Errno::EACCES => e
      AuthorizationResult.new(status: :unknown, success: false, error: HelperSpawnError.new(e.message))
    end

    private

    def run(*args)
      Open3.capture3(@helper_path, *args)
    end

    def error_for(exit_code, stderr)
      klass = EXIT_CODE_ERRORS[exit_code]
      return klass.new(stderr) if klass
      return Error.new(stderr) if exit_code == 6
      HelperCrashError.new(stderr.empty? ? "exit #{exit_code}" : stderr)
    end
  end
end
