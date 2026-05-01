# frozen_string_literal: true

require "swift_gem/mkmf"

SwiftGem::Mkmf.create_swift_makefile(
  "speech_mac/speech_mac",
  package: "SpeechMac",
  source_dir: __dir__
)
