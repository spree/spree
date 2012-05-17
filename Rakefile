require 'rake'
require 'rubygems/package_task'
require 'thor/group'
require File.expand_path('../core/lib/generators/spree/install/install_generator', __FILE__)
require 'spree/core/testing_support/common_rake'

spec = eval(File.read('spree.gemspec'))
Gem::PackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

desc "Generates a dummy app for testing for every Spree engine"
task :test_app do
  %w(api auth core dash promo).each do |engine|
    ENV['LIB_NAME'] = File.join('spree', engine)
    ENV['DUMMY_PATH'] = File.expand_path("../#{engine}/spec/dummy", __FILE__)
    Rake::Task['common:test_app'].execute
  end
end

desc "Run all tests for all supported databases"
task :ci do
  cmd = "bundle update"; puts cmd; system cmd;

  %w(sqlite3 mysql).each do |database_name|
    run_all_tests(database_name)
  end
end

desc "clean the whole repository by removing all the generated files"
task :clean do
  puts "Deleting sandbox..."
  FileUtils.rm_rf("sandbox")
  puts "Deleting pkg directory.."
  FileUtils.rm_rf("pkg")

  %w(api auth cmd core dash promo).each do |gem_name|
    puts "Cleaning #{gem_name}:"
    puts "  Deleting #{gem_name}/Gemfile"
    FileUtils.rm_f("#{gem_name}/Gemfile")
    puts "  Deleting #{gem_name}/pkg"
    FileUtils.rm_rf("#{gem_name}/pkg")
    puts "  Deleting #{gem_name}'s dummy application"
    Dir.chdir("#{gem_name}/spec") do
      FileUtils.rm_rf("dummy")
    end
  end
end

namespace :gem do
  desc "run rake gem for all gems"
  task :build do
    %w(core auth api dash promo sample cmd).each do |gem_name|
      puts "########################### #{gem_name} #########################"
      puts "Deleting #{gem_name}/pkg"
      FileUtils.rm_rf("#{gem_name}/pkg")
      cmd = "cd #{gem_name} && bundle exec rake gem"; puts cmd; system cmd
    end
    puts "Deleting pkg directory"
    FileUtils.rm_rf("pkg")
    cmd = "bundle exec rake gem"; puts cmd; system cmd
  end
end

namespace :gem do
  desc "run gem install for all gems"
  task :install do
    version = File.read(File.expand_path("../SPREE_VERSION", __FILE__)).strip

    %w(core auth api dash promo sample cmd).each do |gem_name|
      puts "########################### #{gem_name} #########################"
      puts "Deleting #{gem_name}/pkg"
      FileUtils.rm_rf("#{gem_name}/pkg")
      cmd = "cd #{gem_name} && bundle exec rake gem"; puts cmd; system cmd
      cmd = "cd #{gem_name}/pkg && gem install spree_#{gem_name}-#{version}.gem"; puts cmd; system cmd
    end
    puts "Deleting pkg directory"
    FileUtils.rm_rf("pkg")
    cmd = "bundle exec rake gem"; puts cmd; system cmd
    cmd = "gem install pkg/spree-#{version}.gem"; puts cmd; system cmd
  end
end

namespace :gem do
  desc "Release all gems to gemcutter. Package spree components, then push spree"
  task :release do
    version = File.read(File.expand_path("../SPREE_VERSION", __FILE__)).strip

    %w(core auth api dash promo sample cmd).each do |gem_name|
      puts "########################### #{gem_name} #########################"
      cmd = "cd #{gem_name}/pkg && gem push spree_#{gem_name}-#{version}.gem"; puts cmd; system cmd
    end
    cmd = "gem push pkg/spree-#{version}.gem"; puts cmd; system cmd
  end
end

desc "Creates a sandbox application for simulating the Spree code in a deployed Rails app"
task :sandbox do
  require 'spree_core'

  Spree::SandboxGenerator.start ["--lib_name=spree"]
  Spree::InstallGenerator.start ["--auto-accept"]

  cmd = "bundle exec rake assets:precompile:nondigest"; puts cmd; system cmd
end
