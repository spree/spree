# encoding: UTF-8
Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = '<%= file_name %>'
  s.version     = '<%= Spree.version %>'
  s.summary     = 'TODO: Add gem summary here'
  s.description = 'TODO: Add (optional) gem description here'
  s.required_ruby_version = '>= 1.8.7'

  # s.author            = 'You'
  # s.email             = 'you@example.com'
  # s.homepage          = 'http://www.spreecommerce.com'

  #s.files         = `git ls-files`.split("\n")
  #s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree_core', '>= <%= Spree.version %>'
  s.add_development_dependency 'rspec-rails'
end

