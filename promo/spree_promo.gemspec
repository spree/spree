version = File.read(File.expand_path("../../SPREE_VERSION", __FILE__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_promo'
  s.version     = version
  s.summary     = 'Promotion functionality for use with Spree.'
  s.description = 'Required dependancy for Spree'

  s.required_ruby_version = '>= 1.8.7'
  s.author      = 'David North'
  s.email       = "david@railsdog.com"
  s.homepage    = 'http://spreecommerce.com'
  s.rubyforge_project = 'spree_promo'

  s.files        = Dir['CHANGELOG', 'README', 'MIT-LICENSE', 'app/**/*', 'config/**/*', 'lib/**/*', 'db/**/*', 'public/**/*']
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency('spree_core',  version)
end
