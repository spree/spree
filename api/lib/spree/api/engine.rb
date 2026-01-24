require 'rails/engine'
require 'pagy'

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
        Migrations.new(config, engine_name).check unless Rails.env.test?
      end

      # Configure typelizer for TypeScript type generation
      # Runs after typelizer.configure so we can override defaults
      initializer 'spree.api.typelizer', after: 'typelizer.configure' do
        next unless defined?(Typelizer)

        api_root = Spree::Api::Engine.root

        Typelizer.configure do |config|
          config.dirs = [
            api_root.join('app/serializers/spree/api/v3'),
            api_root.join('app/serializers/spree/api/v3/admin')
          ]
          config.output_dir = api_root.join('../sdk/src/types/generated')
          config.comments = true

          # Type names: StoreProduct, AdminProduct, etc.
          config.serializer_name_mapper = ->(serializer) {
            name = serializer.name.to_s
              .sub(/\ASpree::Api::V3::Admin::/, 'Admin')
              .sub(/\ASpree::Api::V3::/, 'Store')
              .sub(/Serializer\z/, '')
            name
          }
        end
      end

      # Add API event subscribers
      config.after_initialize do
        Spree.subscribers << Spree::WebhookEventSubscriber
      end

      def self.root
        @root ||= Pathname.new(File.expand_path('../../..', __dir__))
      end
    end
  end
end
