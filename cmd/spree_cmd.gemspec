# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
version = File.read(File.expand_path("../../SPREE_VERSION", __FILE__)).strip

Gem::Specification.new do |s|
  s.name        = "spree_cmd"
  s.version     = version
  s.authors     = ["Chris Mar"]
  s.email       = ["chris@spreecommerce.com"]
  s.homepage    = "http://spreecommerce.com"
  s.summary     = %q{Spree Commerce command line utility}
  s.description = %q{tools to create new Spree stores and extensions}

  s.rubyforge_project = "spree_cmd"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.bindir        = 'bin'
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency 'rspec'
  # Temporary hack until https://github.com/wycats/thor/issues/234 is fixed
  s.add_dependency 'thor', '0.14.6'
end
