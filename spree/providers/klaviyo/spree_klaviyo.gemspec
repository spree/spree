require_relative '../../core/lib/spree/core/version'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_klaviyo'
  s.version     = Spree.version
  s.authors     = ['Vendo Connect Inc.', 'Vendo Sp. z o.o.']
  s.email       = 'hello@spreecommerce.org'
  s.summary     = 'Official Klaviyo marketing integration for Spree Commerce'
  s.description = 'Syncs customer profiles, newsletter sign-ups, orders, shipments and refunds to Klaviyo, ' \
                  'and lets Klaviyo send the newsletter confirmation and order emails.'
  s.homepage    = 'https://spreecommerce.org'
  s.license     = 'MIT'

  s.metadata = {
    'bug_tracker_uri' => 'https://github.com/spree/spree/issues',
    'changelog_uri' => "https://github.com/spree/spree/releases/tag/v#{s.version}",
    'documentation_uri' => 'https://docs.spreecommerce.org/',
    'source_code_uri' => "https://github.com/spree/spree/tree/v#{s.version}"
  }

  s.required_ruby_version = '>= 3.2'

  s.files = Dir['{app,config,db,lib,vendor}/**/*', 'Rakefile', 'LICENSE', 'README.md'].reject do |f|
    f.match(/^spec/) && !f.match(%r{^spec/fixtures})
  end
  s.require_path = 'lib'

  s.add_dependency 'klaviyo-api-sdk', '~> 19.0'
  s.add_dependency 'spree_core', s.version
end
