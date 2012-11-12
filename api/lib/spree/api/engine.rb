require 'rails/engine'

module Spree
  module Api
    class Engine < Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_api'

      config.view_versions = [1]
      config.view_version_extraction_strategy = :http_parameter

      initializer "spree.api.environment", :before => :load_config_initializers do |app|
        Spree::Api::Config = Spree::ApiConfiguration.new
      end

      def self.activate
        Dir.glob(File.join(File.dirname(__FILE__), "../../../app/**/*_decorator*.rb")) do |c|
          Rails.configuration.cache_classes ? require(c) : load(c)
        end
      end
      config.to_prepare &method(:activate).to_proc

      def self.root
        @root ||= Pathname.new(File.expand_path('../../../../', __FILE__))
      end
    end
  end
end


