require "rails/generators/rails/app/app_generator"

module Spree
  class SandboxGenerator < Spree::DummyGenerator
    desc "Creates blank Rails application, installs Spree and all sample data"

    def self.source_paths
      paths = self.superclass.source_paths
      paths.unshift File.expand_path('../templates', __FILE__)
      paths.flatten
    end

    def drop_database
      say "dropping database"
      inside dummy_path do
        quietly do
          rake 'db:drop -f sandbox/Rakefile'
        end
      end
    end

    def use_spree_auth_devise
      inside dummy_path do
        File.open("Gemfile", "a+") do |f|
          f.write %Q{gem 'spree_auth_devise', :git => "git://github.com/radar/spree_auth_devise"}
        end
      end
      run 'bundle install'
    end

    protected
    def dummy_path
      'sandbox'
    end

    def gemfile_path
      '../../../Gemfile'
    end

    def module_name
      'Sandbox'
    end

  end
end
