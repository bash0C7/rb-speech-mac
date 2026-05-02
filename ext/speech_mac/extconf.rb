# frozen_string_literal: true

BUNDLE_ID = "com.bash0c7.rb-speech-mac.helper"
BUILD_PATH = ".build/release/SpeechMacHelper"

def detect_codesign_identity
  override = ENV["SPEECH_MAC_CODESIGN_IDENTITY"]
  return override if override && !override.empty?

  output = `security find-identity -v -p codesigning 2>/dev/null`
  if (m = output.match(/"(Apple Development:[^"]+)"/))
    return m[1]
  end

  "-"
end

source_dir = __dir__
gem_root = File.expand_path("../..", source_dir)
install_path = File.join(gem_root, "lib", "speech_mac", "SpeechMacHelper")
identity = detect_codesign_identity

File.write("Makefile", <<MAKEFILE)
.PHONY: all build install clean distclean

INSTALL_PATH = #{install_path}
DEST_PATH = $(DESTDIR)$(INSTALL_PATH)
BUILD_PATH = #{BUILD_PATH}
IDENTITY = #{identity}
BUNDLE_ID = #{BUNDLE_ID}

all: build

build: $(BUILD_PATH)

$(BUILD_PATH):
\tswift build -c release --package-path .
\tcodesign -s "$(IDENTITY)" --force --identifier "$(BUNDLE_ID)" --options runtime $@

install: $(DEST_PATH)

$(DEST_PATH): $(BUILD_PATH)
\t@mkdir -p $(dir $(DEST_PATH))
\tinstall -m 755 $(BUILD_PATH) $(DEST_PATH)

clean:
\tswift package clean
\trm -rf .build

distclean: clean
\trm -f Makefile
MAKEFILE

puts "[rb-speech-mac] codesign identity: #{identity}"
puts "[rb-speech-mac] install target:    #{install_path}"
