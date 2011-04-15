require 'rake'
require 'rake/gempackagetask'
require 'thor/group'

spec = eval(File.read('spree.gemspec'))
Rake::GemPackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

task :default => [:spec, :cucumber ]

desc "clean the whole repository by removing all the generated files"
task :clean do
  cmd = "rm -rf sandbox"; puts cmd; system cmd
  %w(api auth core dash promo).each do |gem_name|
    cmd = "rm #{gem_name}/Gemfile*"; puts cmd; system cmd
    cmd = "cd #{gem_name}/spec &&  rm -rf test_app"; puts cmd; system cmd
  end
end

desc "run all tests for ci"
task :ci do
  cmd = "bundle update"; puts cmd; system cmd;

  %w(sqlite3 mysql).each do |database_name|
    %w(api auth core promo).each do |gem_name|
      puts "########################### #{gem_name}|#{database_name} (features) ###########################"
      cmd = "rm #{gem_name}/Gemfile*"; puts cmd; system cmd
      sh "cd #{gem_name} && #{$0} test_app DB_NAME='#{database_name}'"
      sh "cd #{gem_name} && bundle exec cucumber -p ci"
    end

    %w(api auth core dash promo).each do |gem_name|
      puts "########################### #{gem_name}|#{database_name} (spec) ###########################"
      cmd = "rm #{gem_name}/Gemfile*"; puts cmd; system cmd
      sh "cd #{gem_name} && #{$0} test_app DB_NAME='#{database_name}'"
      sh "cd #{gem_name} && #{$0} spec"
    end
  end
end

desc "run spec test for all gems"
task :spec do
  %w(api auth core dash promo).each do |gem_name|
    puts "########################### #{gem_name} #########################"
    cmd = "rm #{gem_name}/Gemfile*"; puts cmd; system cmd
    cmd = "cd #{gem_name} && #{$0} test_app"; puts cmd; system cmd
    cmd = "cd #{gem_name} && #{$0} spec"; puts cmd; system cmd
  end
end

desc "run cucumber test for all gems"
task :cucumber do
  %w(api auth core promo).each do |gem_name|
    puts "########################### #{gem_name} #########################"
    cmd = "rm #{gem_name}/Gemfile*"; puts cmd; system cmd
    cmd = "cd #{gem_name} && rake test_app"; puts cmd; system cmd
    cmd = "cd #{gem_name} && bundle exec cucumber -p ci"; puts cmd; system cmd
  end
end

namespace :gem do
  desc "run rake gem for all gems"
  task :build do
    %w(core auth api dash promo sample).each do |gem_name|
      puts "########################### #{gem_name} #########################"
      cmd = "rm -rf #{gem_name}/pkg"; puts cmd; system cmd
      cmd = "cd #{gem_name} && rake gem"; puts cmd; system cmd
    end
    cmd = "rm -rf pkg"; puts cmd; system cmd
    cmd = "rake gem"; puts cmd; system cmd
  end
end

namespace :gem do
  desc "run gem install for all gems"
  task :install do
    version = File.read(File.expand_path("../SPREE_VERSION", __FILE__)).strip

    %w(core auth api dash promo sample).each do |gem_name|
      puts "########################### #{gem_name} #########################"
      cmd = "rm #{gem_name}/pkg"; puts cmd; system cmd
      cmd = "cd #{gem_name} && rake gem"; puts cmd; system cmd
      cmd = "cd #{gem_name}/pkg && gem install spree_#{gem_name}-#{version}.gem"; puts cmd; system cmd
    end
    cmd = "rm -rf pkg"; puts cmd; system cmd
    cmd = "rake gem"; puts cmd; system cmd
    cmd = "gem install pkg/spree-#{version}.gem"; puts cmd; system cmd
  end
end

namespace :gem do
  desc "Release all gems to gemcutter. Package spree components, then push spree"
  task :release do
    version = File.read(File.expand_path("../SPREE_VERSION", __FILE__)).strip

    %w(core auth api dash promo sample).each do |gem_name|
      puts "########################### #{gem_name} #########################"
      cmd = "cd #{gem_name}/pkg && gem push spree_#{gem_name}-#{version}.gem"; puts cmd; system cmd
    end
    cmd = "gem push pkg/spree-#{version}.gem"; puts cmd; system cmd
  end
end

desc "Creates a sandbox application for testing your Spree code"
task :sandbox do

  class SandboxGenerator < Thor::Group
    include Thor::Actions

    def generate_app
      remove_directory_if_exists("sandbox")
      run "rails new sandbox -GJT"
    end

    def append_gemfile
      inside "sandbox" do
        append_file "Gemfile" do
<<-gems
          gem 'spree', :path => '../' \n
          if RUBY_VERSION < "1.9"
            gem "ruby-debug"
          else
            gem "ruby-debug19"
          end

gems
        end
      end
    end

    def install_generators
      inside "sandbox" do
        run 'rails g spree:site -f'
        run 'rake spree:install'
        run 'rake spree_sample:install'
      end
    end

    def run_bootstrap
      inside "sandbox" do
        run 'rake db:bootstrap AUTO_ACCEPT=true'
      end
    end

    private
    def remove_directory_if_exists(path)
      run "rm -r #{path}" if File.directory?(path)
    end
  end

  SandboxGenerator.start
end
