require 'rake'
require 'rake/gempackagetask'
require 'thor/group'

spec = eval(File.read('spree.gemspec'))
Rake::GemPackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

task :default => [ :spec ]

desc "run spec test for all gems"
task :spec do
  %w(api auth core dash promo).each do |gem_name|
    cmd = "rm #{gem_name}/Gemfile"; puts cmd; system cmd
    cmd = "cd #{gem_name} && #{$0} test_app"; puts cmd; system cmd
    cmd = "cd #{gem_name} && #{$0} spec"; puts cmd; system cmd
  end
end

desc "run cucumber test for all gems"
task :cucumber do
  %w(api auth core dash promo).each do |gem_name|
    cmd = "rm #{gem_name}/Gemfile"; puts cmd; system cmd
    cmd = "cd #{gem_name} && rake test_app"; puts cmd; system cmd
    cmd = "cd #{gem_name} && bundle exec cucumber"; puts cmd; system cmd
  end
end

desc "Release all gems to gemcutter. Package rails, package & push components, then push spree"
task :release => :release_projects do
  require 'rake/gemcutter'
  Rake::Gemcutter::Tasks.new(spec).define
  Rake::Task['gem:push'].invoke
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
