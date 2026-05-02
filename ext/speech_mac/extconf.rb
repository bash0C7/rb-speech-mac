# frozen_string_literal: true

BUNDLE_ID = "com.bash0c7.rb-speech-mac.helper"
BUILD_PATH = ".build/release/SpeechMacHelper"

def detect_codesign_identity
  override = ENV["SPEECH_MAC_CODESIGN_IDENTITY"]
  return override if override && !override.empty?

  output = `security find-identity -v -p codesigning 2>/dev/null`
  candidates = output.scan(/"(Apple Development:[^"]+)"/).flatten
  case candidates.size
  when 0
    "-"
  when 1
    candidates.first
  else
    warn "[rb-speech-mac] multiple Apple Development certs found:"
    candidates.each { |c| warn "[rb-speech-mac]   #{c}" }
    warn "[rb-speech-mac] using first; set SPEECH_MAC_CODESIGN_IDENTITY to choose explicitly"
    candidates.first
  end
end

# Escape '$' so Make doesn't interpret values as variable references
def make_escape(string)
  string.gsub("$", "$$")
end

source_dir = __dir__
gem_root = File.expand_path("../..", source_dir)
install_path = File.join(gem_root, "lib", "speech_mac", "SpeechMacHelper")
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
\tswift build -c release --package-path .
\tcodesign -s '$(IDENTITY)' --force --identifier '$(BUNDLE_ID)' --options runtime '$(BUILD_PATH)'

install: build
\t@mkdir -p '$(DEST_DIR)'
\tinstall -m 755 '$(BUILD_PATH)' '$(DEST_PATH)'

clean:
\tswift package clean
\trm -rf .build

distclean: clean
\trm -f Makefile
MAKEFILE

puts "[rb-speech-mac] codesign identity: #{identity}"
puts "[rb-speech-mac] install target:    #{install_path}"
