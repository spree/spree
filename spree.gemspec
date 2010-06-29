version = File.read(File.expand_path("../SPREE_VERSION",__FILE__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree'
  s.version     = version
  s.summary     = 'Full-stack e-commerce framework for Ruby on Rails.'
  s.description = ''

  s.required_ruby_version     = '>= 1.8.7'
  s.required_rubygems_version = ">= 1.3.6"

  s.author            = 'Sean Schofield'
  s.email             = 'sean@railsdog.com'
  s.homepage          = 'http://spreecommerce.com'
  s.rubyforge_project = 'spree'

  s.bindir             = 'bin'
  s.executables        = ['spree']
  s.default_executable = 'spree'

  s.add_dependency('spree_core',                version)
  s.add_dependency('spree_payment_gateway',     version)
  s.add_dependency('spree_api',                 version)
  s.add_dependency('spree_dashboard',           version)
  s.add_dependency('spree_sample',              version)
  # RAILS3 TODO - add more of the core extensions, etc.
  s.add_dependency('bundler',        '>= 0.9.26')
  s.add_dependency('rails',          '= 3.0.0.beta4')
  s.add_dependency('highline',       '>= 1.5.1')
  s.add_dependency('authlogic',      '>= 2.1.5')
  s.add_dependency('activemerchant')
  s.add_dependency('activerecord-tableless', '>= 0.1.0')
  s.add_dependency('less', '>= 1.2.20')
  s.add_dependency('stringex',       '>= 1.0.3')
  s.add_dependency('will_paginate')
  s.add_dependency('state_machine',  '>= 0.9.2')
  s.add_dependency('faker',          '>= 0.3.1')
  s.add_dependency('paperclip',      '>= 2.3.1.1')
  s.add_dependency('resource_controller')

end