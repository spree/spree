# encoding: UTF-8

require_relative '../core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_legacy_emails'
  s.version     = Spree.version
  s.authors     = ['Vendo Connect Inc.']
  s.email       = 'hello@spreecommerce.org'
  s.summary     = 'The pre-6.0 ERB transactional emails for Spree, kept for one release'
  s.description = 'Keeps the ERB email templates, and ERB overrides of them, rendering in Spree 6.0 while they are ported to Liquid. Deprecated; removed in Spree 6.1.'
  s.homepage    = 'https://spreecommerce.org'
  s.license     = 'BSD-3-Clause'

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/spree/spree/issues",
    "changelog_uri"     => "https://github.com/spree/spree/releases/tag/v#{s.version}",
    "documentation_uri" => "https://docs.spreecommerce.org/",
    "source_code_uri"   => "https://github.com/spree/spree/tree/v#{s.version}",
  }

  s.required_ruby_version = '>= 3.2'

  s.files        = Dir["{app,lib}/**/*", "LICENSE", "README.md"]
  s.require_path = 'lib'

  s.add_dependency 'spree_emails', s.version

  s.add_development_dependency 'email_spec', '~> 2.2'
end
