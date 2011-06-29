require 'rails/generators'
require File.expand_path('../../../../core/lib/generators/spree_core/site/site_generator', __FILE__)

module Spree
  module Generators
    class SiteGenerator < SpreeCore::Generators::SiteGenerator
      desc "Configures an existing Rails application to use Spree."
      #dummy generator, just inherits from spree_core
    end
  end
end
