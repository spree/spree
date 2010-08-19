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

  #s.bindir             = 'bin'
  #s.executables        = ['spree']
  #s.default_executable = 'spree'

  s.add_dependency('spree_core',                version)
  s.add_dependency('spree_auth',                version)
  s.add_dependency('spree_api',                 version)
  s.add_dependency('spree_dashboard',           version)
  s.add_dependency('spree_sample',              version)
  s.add_dependency('spree_promotions',          version)
end
