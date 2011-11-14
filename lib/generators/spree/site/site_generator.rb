require 'rails/generators'
require File.expand_path('../../install/install_generator', __FILE__)

module Spree
  class SiteGenerator < Rails::Generators::Base
    class_option :auto_accept, :type => :boolean, :default => false, :aliases => '-A', :desc => "Answer yes to all prompts"

    def deprecated
      puts ActiveSupport::Deprecation.warn "rails g spree:site is deprecated and may be removed from future releases, use rails g spree:install instead."
    end

    def run_install_generator
      if options[:auto_accept]
        Spree::InstallGenerator.start ["--auto-accept"]
      else
        Spree::InstallGenerator.start
      end
    end
  end
end
