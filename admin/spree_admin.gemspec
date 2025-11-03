# encoding: UTF-8

require_relative '../core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_admin'
  s.version     = Spree.version
  s.authors     = ['Vendo Connect Inc.']
  s.email       = 'hello@spreecommerce.org'
  s.summary     = 'Admin Dashboard for Spree Commerce developed by Vendo Connect Inc.'
  s.description = 'Fully featured Admin Dashboard for Spree Commerce. Manage your store, orders, products, and more.'
  s.homepage    = 'https://getvendo.com'
  s.license     = 'AGPL-3.0-or-later'

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/spree/spree/issues",
    "changelog_uri"     => "https://github.com/spree/spree/releases/tag/v#{s.version}",
    "documentation_uri" => "https://docs.spreecommerce.org/",
    "source_code_uri"   => "https://github.com/spree/spree/tree/v#{s.version}",
  }

  s.required_ruby_version     = '>= 3.0'
  s.required_rubygems_version = '>= 1.8.23'

  s.files        = Dir["{app,config,db,lib,vendor}/**/*", "LICENSE.md", "Rakefile", "README.md"].reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.require_path = 'lib'

  s.add_dependency 'spree_core', ">= #{s.version}"
  s.add_dependency 'spree_api', ">= #{s.version}"

  s.add_dependency 'active_link_to'
  s.add_dependency 'bootstrap', '~> 4.6', '>= 4.6.2.1'
  s.add_dependency 'breadcrumbs_on_rails', '~> 4.1'
  s.add_dependency 'chartkick', '~> 5.0'
  s.add_dependency 'dartsass-rails', '~> 0.5'
  s.add_dependency 'groupdate', '~> 6.2'
  s.add_dependency 'hightop', '~> 0.3'
  s.add_dependency 'importmap-rails'
  s.add_dependency 'inline_svg', '~> 1.10'
  s.add_dependency 'local_time', '~> 3.0'
  s.add_dependency 'mapkick-rb', '~> 0.1'
  s.add_dependency 'turbo-rails'
  s.add_dependency 'stimulus-rails'
  s.add_dependency 'tinymce-rails', '~> 6.8.5'
end
