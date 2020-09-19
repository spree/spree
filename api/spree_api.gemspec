# -*- encoding: utf-8 -*-
require_relative '../core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.name          = "spree_api"
  s.version       = Spree.version
  s.authors       = ["Ryan Bigg"]
  s.email         = ["ryan@spreecommerce.com"]
  s.summary       = %q{Spree's API}
  s.description   = %q{Spree's API}
  s.homepage      = 'https://spreecommerce.org'
  s.license       = 'BSD-3-Clause'

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/spree/spree/issues",
    "changelog_uri"     => "https://github.com/spree/spree/releases/tag/v#{s.version}",
    "documentation_uri" => "https://guides.spreecommerce.org/",
    "source_code_uri"   => "https://github.com/spree/spree/tree/v#{s.version}",
  }

  s.required_ruby_version = '>= 2.5.0'

  s.files         = `git ls-files`.split($\).reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.executables   = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency 'jsonapi-rspec'

  s.add_dependency 'spree_core', s.version
  s.add_dependency 'rabl', '~> 0.14.2'
  s.add_dependency 'fast_jsonapi', '~> 1.5'
  s.add_dependency 'doorkeeper', '~> 5.2', '>= 5.2.1'
end
