require "rails/generators/rails/app/app_generator"

module Spree
  class SandboxGenerator < Spree::DummyGenerator
    desc "Creates blank Rails application, installs Spree and all sample data"

    class_option :database, :default => ''

    def self.source_paths
      paths = self.superclass.source_paths
      paths.unshift File.expand_path('../templates', __FILE__)
      paths.flatten
    end

    # skip cucumber environment for sandbox
    def cucumber_environment
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
