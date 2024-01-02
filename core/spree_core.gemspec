# encoding: UTF-8

require_relative 'lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_core'
  s.version     = Spree.version
  s.authors     = ['Sean Schofield', 'Spark Solutions']
  s.email       = 'hello@spreecommerce.org'
  s.summary     = 'The bare bones necessary for Spree'
  s.description = 'Spree Models, Helpers, Services and core libraries'
  s.homepage    = 'https://spreecommerce.org'
  s.license     = 'BSD-3-Clause'

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/spree/spree/issues",
    "changelog_uri"     => "https://github.com/spree/spree/releases/tag/v#{s.version}",
    "documentation_uri" => "https://dev-docs.spreecommerce.org/",
    "source_code_uri"   => "https://github.com/spree/spree/tree/v#{s.version}",
  }

  s.required_ruby_version     = '>= 3.0'
  s.required_rubygems_version = '>= 1.8.23'

  s.files        = `git ls-files`.split("\n").reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.require_path = 'lib'

  %w[
    actionpack actionview activejob activemodel activerecord
    activestorage activesupport railties
  ].each do |rails_gem|
    s.add_dependency rails_gem, '>= 6.1', '< 7.2'
  end

  s.add_dependency 'activemerchant', '~> 1.67'
  s.add_dependency 'acts_as_list', '>= 0.8'
  s.add_dependency 'auto_strip_attributes', '~> 2.6'
  s.add_dependency 'awesome_nested_set', '~> 3.3', '>= 3.3.1'
  s.add_dependency 'carmen', '>= 1.0'
  s.add_dependency 'cancancan', '~> 3.2'
  s.add_dependency 'friendly_id', '~> 5.2', '>= 5.2.1'
  s.add_dependency 'highline', '~> 2.0' # Necessary for the install generator
  s.add_dependency 'kaminari', '~> 1.2'
  s.add_dependency 'money', '~> 6.13'
  s.add_dependency 'monetize', '~> 1.9'
  s.add_dependency 'paranoia', '~> 2.4'
  s.add_dependency 'ransack', '>= 4.1'
  s.add_dependency 'rexml'
  s.add_dependency 'state_machines-activerecord', '~> 0.6'
  s.add_dependency 'state_machines-activemodel', '~> 0.7'
  s.add_dependency 'stringex'
  s.add_dependency 'validates_zipcode'
  s.add_dependency 'image_processing', '~> 1.2'
  s.add_dependency 'active_storage_validations', '~> 1.1.0'
  s.add_dependency 'activerecord-typedstore'
  s.add_dependency 'mobility', '~> 1.2.9'
  s.add_dependency 'mobility-ransack', '~> 1.2.1'
  s.add_dependency 'friendly_id-mobility', '~> 1.0.4'
end
