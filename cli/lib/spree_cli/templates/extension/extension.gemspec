# encoding: UTF-8
lib = File.expand_path('../lib/', __FILE__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

require '<%= file_name %>/version'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = '<%= file_name %>'
  s.version     = <%= class_name %>::VERSION
  s.summary     = "Spree Commerce <%= human_name %> Extension"
  s.required_ruby_version = '>= 3.0'

  s.author    = 'You'
  s.email     = 'you@example.com'
  s.homepage  = 'https://github.com/your-github-handle/<%= file_name %>'
  s.license = 'AGPL-3.0-or-later'

  s.files        = Dir["{app,config,db,lib,vendor}/**/*", "LICENSE.md", "Rakefile", "README.md"].reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree', '>= <%= Gem.loaded_specs['spree_cli'].version %>'
  s.add_dependency 'spree_storefront', '>= <%= Gem.loaded_specs['spree_cli'].version %>'
  s.add_dependency 'spree_admin', '>= <%= Gem.loaded_specs['spree_cli'].version %>'
  s.add_dependency 'spree_extension'

  s.add_development_dependency 'spree_dev_tools'
end
