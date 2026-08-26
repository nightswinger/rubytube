require_relative "lib/rubytube"

Gem::Specification.new do |spec|
  spec.name = "rubytube"
  spec.version = RubyTube::VERSION
  spec.authors = ["nightswinger"]
  spec.email = ["stardustkids83@gmail.com"]

  spec.summary = "Download YouTube videos from Ruby: picks the best video and audio tracks and muxes them with ffmpeg."
  spec.homepage = "https://github.com/nightswinger/rubytube"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE.txt"]
  spec.require_paths = ["lib"]
end
