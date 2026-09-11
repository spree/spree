# encoding: UTF-8

require_relative '../core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_assistant'
  s.version     = Spree.version
  s.authors     = ['Spark Solutions Sp. z o.o.', 'Vendo Connect Inc.']
  s.email       = 'hello@spreecommerce.org'
  s.summary     = 'AI assistant for the Spree admin dashboard'
  s.description = 'Embedded chat assistant for the Spree dashboard — answers questions about store data and performs merchant tasks through permission-gated tools, with every change held for human approval'
  s.homepage    = 'https://spreecommerce.org'
  s.license     = 'BSD-3-Clause'

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/spree/spree/issues",
    "changelog_uri"     => "https://github.com/spree/spree/releases/tag/v#{s.version}",
    "documentation_uri" => "https://docs.spreecommerce.org/",
    "source_code_uri"   => "https://github.com/spree/spree/tree/v#{s.version}",
  }

  s.required_ruby_version = '>= 3.2'

  s.files        = Dir["{app,config,db,lib,vendor}/**/*", "Rakefile", "README.md"].reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.require_path = 'lib'

  s.add_dependency 'spree_core', ">= #{s.version}"
  s.add_dependency 'spree_api', ">= #{s.version}"

  # Pinned deliberately: RubyLLM 2.0 removes the Tool::Halt mechanism the
  # approval gate stands on, replacing it with a first-class `requires_approval`.
  # The upgrade is wanted, but it must stay a one-file change — see
  # docs/plans/6.0-dashboard-assistant.md.
  s.add_dependency 'ruby_llm', '~> 2.0.0.rc2'
end
