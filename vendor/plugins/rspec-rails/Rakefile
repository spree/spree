$:.unshift('lib')
require 'rake'
require 'rake/rdoctask'
require 'rubygems'
require 'rake/gempackagetask'

begin
  
  module Spec
    module VERSION
      BUILD_TIME_UTC = 'place_holder'
    end
  end  
  
  require 'spec/rails/version'

rescue
  # Catch the BUILD_TIME_UTC verification exception.
  # This exception is not relevant when running these tasks and hinders the gem installation.
end

desc 'Generate RDoc'
rd = Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = '../doc/output/rdoc-rails'
  rdoc.options << '--title' << 'Spec::Rails' << '--line-numbers' << '--inline-source' << '--main' << 'Spec::Rails'
  rdoc.rdoc_files.include('MIT-LICENSE', 'lib/**/*.rb')
end

PKG_NAME = "rspec-rails"
PKG_VERSION   = Spec::Rails::VERSION::STRING
PKG_FILE_NAME = "#{PKG_NAME}-#{PKG_VERSION}"
PKG_FILES = FileList[
  '[A-Z]*',
  'lib/**/*.rb', 
  'spec/**/*',
  'spec_resources/**/*',
  'generators/**/*',
  'stories/**/*',
  'tasks/**/*'
]

rspec_rails = Gem::Specification.new do |s|
  s.name = PKG_NAME
  s.version = PKG_VERSION
  s.summary = Spec::Rails::VERSION::DESCRIPTION
  s.description = <<-EOF
    rpsec-rails is a Ruby on Rails plugin that allows you to drive the development
    of your RoR application using RSpec, a framework that aims to enable BDD in Ruby.
  EOF

  s.files = PKG_FILES.to_a
  s.require_path = 'lib'

  s.has_rdoc = true
  s.rdoc_options = rd.options

  s.author = "RSpec Development Team"
  s.email = "rspec-devel@rubyforge.org"
  s.homepage = Spec::Rails::VERSION::URL  
  s.platform = Gem::Platform::RUBY
end

Rake::GemPackageTask.new(rspec_rails) do |pkg|
end
