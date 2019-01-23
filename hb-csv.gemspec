# frozen_string_literal: true

require_relative "lib/hb_csv/version"

Gem::Specification.new do |spec|
  spec.name          = "hb_csv"
  spec.version       = HBCSV::VERSION
  spec.authors       = ["James Edward Gray II", "Kouhei Sutou"]
  spec.email         = [nil, "kou@cozmixng.org"]

  spec.summary       = "HBCSV Reading and Writing"
  spec.description   = "The HBCSV library provides a complete interface to HBCSV files and data. It offers tools to enable you to read and write to and from Strings or IO objects, as needed."
  spec.homepage      = "https://github.com/Hummingbird-RegTech/hb-csv"
  spec.license       = "BSD-2-Clause"

  spec.files         = Dir.glob("lib/**/*.rb")
  spec.files         += ["README.md", "LICENSE.txt", "news.md"]
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 2.3.0"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "benchmark-ips"
end
