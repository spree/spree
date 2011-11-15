require 'rails/generators'
require File.expand_path('../../install/install_generator', __FILE__)

module Spree
  class SiteGenerator < Rails::Generators::Base
    class_option :auto_accept, :type => :boolean, :default => false, :aliases => '-A', :desc => "Answer yes to all prompts"

    def run_install_generator
      if options[:auto_accept]
        Spree::InstallGenerator.start ["--auto-accept"]
      else
        Spree::InstallGenerator.start
      end

      puts ActiveSupport::Deprecation.warn "rails g spree:site has been deprecated and will be removed in the future, use rails g spree:install instead."
    end
  end
end
