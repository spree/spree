require_relative '../core/lib/spree/core/version'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_storefront'
  s.version     = Spree.version
  s.authors     = ['Vendo Connect Inc.']
  s.email       = 'hello@spreecommerce.org'
  s.summary     = 'Modern fully featured storefront and checkout for Spree Commerce'
  s.description = 'Modern fully featured storefront and checkout for Spree Commerce'
  s.homepage    = 'https://getvendo.com'
  s.license     = 'AGPL-3.0-or-later'

  s.metadata = {
    'bug_tracker_uri' => 'https://github.com/spree/spree/issues',
    'changelog_uri' => "https://github.com/spree/spree/releases/tag/v#{s.version}",
    'documentation_uri' => 'https://docs.spreecommerce.org/',
    'source_code_uri' => "https://github.com/spree/spree/tree/v#{s.version}",
  }

  s.required_ruby_version     = '>= 3.0'
  s.required_rubygems_version = '>= 1.8.23'

  s.files        = Dir["{app,config,db,lib,vendor}/**/*", "LICENSE.md", "Rakefile", "README.md"].reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.require_path = 'lib'

  s.add_dependency 'spree_core', ">= #{s.version}"

  s.add_dependency 'active_link_to'
  s.add_dependency 'canonical-rails', '~> 0.2.14'
  s.add_dependency 'heroicon'
  s.add_dependency 'importmap-rails'
  s.add_dependency 'inline_svg', '~> 1.10'
  s.add_dependency 'local_time', '~> 3.0'
  s.add_dependency 'mail_form'
  s.add_dependency 'stimulus-rails'
  s.add_dependency 'tailwindcss-rails'
  s.add_dependency 'tailwindcss-ruby'
  s.add_dependency 'turbo-rails'
end
