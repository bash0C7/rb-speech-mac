# frozen_string_literal: true

require_relative "speech_mac/version"
require_relative "speech_mac/errors"
require_relative "speech_mac/result"
require_relative "speech_mac/helper_client"

module SpeechMac
  DEFAULT_HELPER_PATH = File.expand_path("speech_mac/SpeechMacHelper", __dir__)

  class << self
    def helper_path
      @helper_path ||= DEFAULT_HELPER_PATH
    end

    attr_writer :helper_path

    def transcribe(path)
      HelperClient.new(helper_path).transcribe(path)
    end
  end
end
