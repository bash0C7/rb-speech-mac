# frozen_string_literal: true

BUNDLE_ID = "com.bash0c7.rb-speech-mac.helper"
BUILD_PATH = ".build/release/SpeechMacHelper"

def detect_codesign_identity
  override = ENV["SPEECH_MAC_CODESIGN_IDENTITY"]
  return override if override && !override.empty?

  `security find-identity -v -p codesigning`[/^\s*\d+\) (\h{40}) "Apple Development: [^"]+"$/, 1] || "-"
end

def make_escape(string)
  string.gsub("$", "$$")
end

install_path = File.expand_path("../../lib/speech_mac/SpeechMacHelper", __dir__)
install_dir = File.dirname(install_path)
identity = detect_codesign_identity

File.write("Makefile", <<MAKEFILE)
.PHONY: all build install clean distclean

INSTALL_PATH = #{make_escape(install_path)}
INSTALL_DIR  = #{make_escape(install_dir)}
DEST_PATH    = $(DESTDIR)$(INSTALL_PATH)
DEST_DIR     = $(DESTDIR)$(INSTALL_DIR)
BUILD_PATH   = #{BUILD_PATH}
IDENTITY     = #{make_escape(identity)}
BUNDLE_ID    = #{BUNDLE_ID}

all: install

build:
\txcrun swift build -c release --package-path . --product SpeechMacHelper
\tcodesign -s '$(IDENTITY)' --force --identifier '$(BUNDLE_ID)' --options runtime '$(BUILD_PATH)'

install: build
\t@mkdir -p '$(DEST_DIR)'
\tinstall -m 755 '$(BUILD_PATH)' '$(DEST_PATH)'

clean:
\trm -rf .build

distclean: clean
\trm -f Makefile
MAKEFILE

puts "[rb-speech-mac] codesign identity: #{identity}"
puts "[rb-speech-mac] install target:    #{install_path}"
