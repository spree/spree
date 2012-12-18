require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/packagetask'
require 'rubygems/package_task'
require 'rspec/core/rake_task'
require 'spree/testing_support/common_rake'
require 'rails/all'

Bundler::GemHelper.install_tasks
RSpec::Core::RakeTask.new

spec = eval(File.read('spree_api.gemspec'))
Gem::PackageTask.new(spec) do |p|
  p.gem_spec = spec
end

desc "Release to gemcutter"
task :release do
  version = File.read(File.expand_path("../../SPREE_VERSION", __FILE__)).strip
  cmd = "cd pkg && gem push spree_api-#{version}.gem"; puts cmd; system cmd
end

task :default => :spec

desc "Generates a dummy app for testing"
task :test_app do
  ENV['LIB_NAME'] = 'spree/api'
  Rake::Task['common:test_app'].invoke
end
