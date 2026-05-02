# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

EXT_DIR = File.expand_path("ext/speech_mac", __dir__)

desc "Build the SpeechMacHelper binary and install it into lib/speech_mac/"
task :compile do
  Dir.chdir(EXT_DIR) do
    sh Gem.ruby, "extconf.rb"
    sh "make", "install"
  end
end

desc "Remove the helper binary and Swift build cache"
task :clean do
  Dir.chdir(EXT_DIR) do
    sh "make", "clean" if File.exist?("Makefile")
  end
  rm_f File.join(__dir__, "lib", "speech_mac", "SpeechMacHelper")
end

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

desc "Start an IRB console with speech_mac loaded"
task console: :compile do
  require "irb"
  $LOAD_PATH.unshift File.expand_path("lib", __dir__)
  require "speech_mac"
  ARGV.clear
  IRB.start
end

task default: :test
