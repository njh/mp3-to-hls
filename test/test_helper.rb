$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'simplecov'

SimpleCov.start

require 'mp3_to_hls'
require 'minitest/autorun'
