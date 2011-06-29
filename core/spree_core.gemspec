version = File.read(File.expand_path("../../SPREE_VERSION", __FILE__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_core'
  s.version     = version
  s.summary     = 'Core e-commerce functionality for the Spree project.'
  s.description = 'Required dependancy for Spree'

  s.required_ruby_version = '>= 1.8.7'
  s.author      = 'Sean Schofield'
  s.email       = 'sean@railsdog.com'
  s.homepage    = 'http://spreecommerce.com'
  s.rubyforge_project = 'spree_core'

  s.files        = Dir['LICENSE', 'README.md', 'app/**/*', 'config/**/*', 'lib/**/*', 'db/**/*', 'public/**/*']
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency('acts_as_list', '= 0.1.3')
  s.add_dependency('nested_set', '= 1.6.7')
  s.add_dependency('rd_unobtrusive_date_picker', '= 0.1.0')
  s.add_dependency('rd_find_by_param', '= 0.1.1')

  s.add_dependency('highline', '= 1.5.1')
  s.add_dependency('stringex', '= 1.0.3')
  s.add_dependency('state_machine', '= 1.0.1')
  s.add_dependency('faker', '= 0.9.5')
  s.add_dependency('paperclip', '= 2.3.11')
  s.add_dependency('rd_resource_controller')
  s.add_dependency('meta_search', '= 1.1.0.pre')
  s.add_dependency('activemerchant', '= 1.15.0')
  s.add_dependency('kaminari', '>= 0.12.2')
  s.add_dependency('deface', '>= 0.5.6')
end
