# -*- encoding: utf-8 -*-
version = File.read(File.expand_path("../../SPREE_VERSION", __FILE__)).strip

Gem::Specification.new do |gem|
  gem.authors       = ["Ryan Bigg"]
  gem.email         = ["ryan@spreecommerce.com"]
  gem.description   = %q{Spree's API}
  gem.summary       = %q{Spree's API}
  gem.homepage      = 'https://spreecommerce.com'
  gem.license       = %q{BSD-3}

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "spree_api"
  gem.require_paths = ["lib"]
  gem.version       = version

  gem.add_dependency 'spree_core', version
  gem.add_dependency 'rabl', '~> 0.11.6'
  gem.add_dependency 'versioncake', '~> 2.3.1'
end
