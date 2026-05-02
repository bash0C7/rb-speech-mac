# frozen_string_literal: true

module SpeechMac
  class Error < StandardError; end
  class NotAuthorizedError < Error; end
  class TimeoutError < Error; end
  class HelperSpawnError < Error; end
  class FileNotFoundError < Error; end
  class RecognizerUnavailableError < Error; end
  class HelperCrashError < Error; end
end
