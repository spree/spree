require "rails/generators/rails/app/app_generator"

module SpreeCore
  class SandboxGenerator < SpreeCore::DummyGenerator
    desc "Creates blank Rails application, installs Spree and all sample data"

    class_option :database, :default => ''

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
