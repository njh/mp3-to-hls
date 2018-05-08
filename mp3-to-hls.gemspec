lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mp3_to_hls/version'

Gem::Specification.new do |spec|
  spec.name          = 'mp3-to-hls'
  spec.version       = MP3toHLS::VERSION
  spec.authors       = ['Nicholas Humfrey']
  spec.email         = ['njh@aelius.com']

  spec.summary       = 'Convert an MP3 file into an HLS stream'
  spec.homepage      = 'https://github.com/njh/mp3-to-hls'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'mp3file', '~> 1.2.0'
  spec.add_development_dependency 'taglib-ruby', '~> 0.7.1'

  spec.add_development_dependency 'bundler', '~> 1.13'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rubocop', '~> 0.55.0'
end
