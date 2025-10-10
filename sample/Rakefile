require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rspec/core/rake_task'
require 'spree/testing_support/common_rake'

RSpec::Core::RakeTask.new

task default: :spec

desc "Generates a dummy app for testing"
task :test_app do
  ENV['LIB_NAME'] = 'spree/sample'
  Rake::Task['common:test_app'].invoke
end
