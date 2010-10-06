require 'rake'
require 'rake/gempackagetask'
require 'thor/group'

PROJECTS = %w(core api auth dash sample)  #TODO - spree_promotions

spec = eval(File.read('spree.gemspec'))
Rake::GemPackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
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
          "gem 'spree', :path => '../' "
        end
      end
    end

    def install_generators
      inside "sandbox" do
        run 'rails g spree_core:install -f'
        run 'rails g spree_auth:install -f'
        run 'rails g spree_api:install -f'
        run 'rails g spree_dash:install -f'
        run 'rails g spree_promo:install -f'
        run 'rails g spree_sample:install -f'
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
# desc "Release all components to gemcutter."
# task :release_projects => :package do
#   errors = []
#   PROJECTS.each do |project|
#     system(%(cd #{project} && #{$0} release)) || errors << project
#   end
#   fail("Errors in #{errors.join(', ')}") unless errors.empty?
# end