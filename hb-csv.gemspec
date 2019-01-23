# frozen_string_literal: true

require_relative "lib/hb_csv/version"

Gem::Specification.new do |spec|
  spec.name          = "hb-csv"
  spec.version       = HBCSV::VERSION
  spec.platform      = Gem::Platform::RUBY
  spec.authors       = ["Jesse Reiss", "Ryan Gerard", "Andrew Kiellor"]
  spec.email         = [nil, "kou@cozmixng.org"]

  spec.summary       = "CSV Reading and Writing"
  spec.description   = "The HBCSV library is a clone of CSV for Hummingbird."
  spec.homepage      = "https://github.com/Hummingbird-RegTech/hb-csv"
  spec.license       = "BSD-2-Clause"

  spec.files         = Dir.glob("lib/**/*.rb") + ["LICENSE.txt"]
  spec.require_path  = "lib"
  spec.required_ruby_version = ">= 2.3.0"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "benchmark-ips"
end
