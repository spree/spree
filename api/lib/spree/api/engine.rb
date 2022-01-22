require 'rails/engine'

require_relative 'dependencies'
require_relative 'configuration'

module Spree
  module Api
    class Engine < Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_api'

      initializer 'spree.api.environment', before: :load_config_initializers do |_app|
        Spree::Api::Config = Spree::Api::Configuration.new
        Spree::Api::Dependencies = Spree::Api::ApiDependencies.new
      end

      initializer 'spree.api.checking_migrations' do
        Migrations.new(config, engine_name).check
      end

      def self.activate
        Dir.glob(File.join(File.dirname(__FILE__), '../../../app/models/spree/api/webhooks/*_decorator*.rb')) do |c|
          Rails.application.config.cache_classes ? require(c) : load(c)
        end
      end

      def self.root
        @root ||= Pathname.new(File.expand_path('../../..', __dir__))
      end

      config.to_prepare &method(:activate).to_proc
    end
  end
end
