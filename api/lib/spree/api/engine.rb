require 'rails/engine'
require 'versioncake'

module Spree
  module Api
    class Engine < Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_api'

      Rabl.configure do |config|
        config.include_json_root = false
        config.include_child_root = false

        # Motivation here it make it call as_json when rendering timestamps
        # and therefore display miliseconds. Otherwise it would fall to
        # JSON.dump which doesn't display the miliseconds
        config.json_engine = ActiveSupport::JSON
      end

      config.versioncake.supported_version_numbers = [1]
      config.versioncake.extraction_strategy = :http_header

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
