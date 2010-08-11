version = File.read(File.expand_path("../../SPREE_VERSION", __FILE__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_core'
  s.version     = version
  s.summary     = 'Core e-commerce functionality for the Spree project.'
  #s.description = 'Email on Rails. Compose, deliver, receive, and test emails using the familiar controller/view pattern. First-class support for multipart email and attachments.'
  s.required_ruby_version = '>= 1.8.7'

  # s.author            = 'David Heinemeier Hansson'
  # s.email             = 'david@loudthinking.com'
  # s.homepage          = 'http://www.rubyonrails.org'
  # s.rubyforge_project = 'actionmailer'

  s.files        = Dir['CHANGELOG', 'README', 'MIT-LICENSE', 'lib/**/*']
  s.require_path = 'lib'
  s.requirements << 'none'

  s.has_rdoc = true

  s.add_dependency('acts_as_list', '>= 0.1.2')
  s.add_dependency('rd_awesome_nested_set', '>= 1.4.4')
  s.add_dependency('rd_stump', '>= 0.0.2')
  s.add_dependency('rd_unobtrusive_date_picker', '>= 0.1.0')
  s.add_dependency('bundler', '>= 0.9.26')
  s.add_dependency('rails', '>= 3.0.0.rc')
  s.add_dependency('highline', '>= 1.5.1')
  s.add_dependency('activerecord-tableless', '>= 0.1.0')
  s.add_dependency('less', '>= 1.2.20')
  s.add_dependency('stringex', '>= 1.0.3')
  s.add_dependency('state_machine', '>= 0.9.4')
  s.add_dependency('faker', '>= 0.3.1')
  s.add_dependency('paperclip', '>= 2.3.1.1')
  s.add_dependency('rd_resource_controller')
  s.add_dependency('rd_searchlogic')
  s.add_dependency('activemerchant', '>= 1.7.1')
  s.add_dependency('will_paginate', '>= 3.0.pre')
end
