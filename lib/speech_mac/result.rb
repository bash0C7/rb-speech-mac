# frozen_string_literal: true

module SpeechMac
  Result = Data.define(:text, :success, :error)
  AuthorizationResult = Data.define(:status, :success, :error)
end
