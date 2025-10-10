# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require_relative '../core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.name        = "spree_cli"
  s.version     = Spree.version
  s.authors     = ['Chris Mar', 'Spark Solutions Sp. z o.o.', 'Vendo Connect Inc.']
  s.email       = ['hello@spreecommerce.org']
  s.summary     = 'Spree Commerce CLI'
  s.description = 'Spree Commerce command line interface'
  s.homepage    = 'https://spreecommerce.org'
  s.licenses    = ['AGPL-3.0-or-later', 'BSD-3-Clause']

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/spree/spree/issues",
    "changelog_uri"     => "https://github.com/spree/spree/releases/tag/v#{s.version}",
    "documentation_uri" => "https://docs.spreecommerce.org/",
    "source_code_uri"   => "https://github.com/spree/spree/tree/v#{s.version}",
  }

  s.files         = Dir.glob(["{app,config,db,lib,vendor}/**/*", "LICENSE.md", "Rakefile", "README.md"], File::FNM_DOTMATCH).reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.bindir        = 'bin'
  s.executables   = Dir['bin/*'].map { |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_dependency 'thor', '~> 1.0'
end
