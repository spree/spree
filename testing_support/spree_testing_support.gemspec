# encoding: UTF-8
version = File.read(File.expand_path("../../SPREE_VERSION", __FILE__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_testing_support'
  s.version     = version
  s.summary     = 'Testing support infrastructure for Spree.'
  s.description = 'Testing support infrastructure for Spree'

  s.required_ruby_version = '>= 1.8.7'
  s.author      = 'Sean Schofield'
  s.email       = 'sean@spreecommerce.com'
  s.homepage    = 'http://spreecommerce.com'
  s.rubyforge_project = 'spree_testing_support'

  s.files       = `git ls-files`.split($/)
  s.require_path = 'lib'
  s.requirements << 'none'
end
