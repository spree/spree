require 'rails/engine'

require_relative 'dependencies'
require_relative 'configuration'
require_relative 'agent_write_schemas'
require_relative 'agent_resource_map'

module Spree
  module Api
    class Engine < Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_api'

      initializer 'spree.api.environment', before: :load_config_initializers do |_app|
        Spree::Api::Config = Spree::Api::Configuration.new
        Spree::Api::Dependencies = Spree::Api::ApiDependencies.new
      end

      initializer 'spree.api.request_size_limit' do |app|
        require_relative 'middleware/request_size_limit'
        app.middleware.insert_before Rack::Runtime, Spree::Api::Middleware::RequestSizeLimit
      end

      # The resources agents may read and write are derived from the admin
      # controllers themselves (see Spree::Api::AgentResourceMap). Marked
      # stale on every reload rather than rebuilt: deriving it eager-loads the
      # application, and doing that on each file save would turn Spree's
      # development reload from lazy into fully eager for everyone, whether or
      # not they run an agent client. The first caller pays instead.
      config.to_prepare do
        Spree::Api::AgentResourceMap.stale!
      end

      # Add API event subscribers
      config.after_initialize do
        Spree.subscribers << Spree::WebhookEventSubscriber
      end

      # Warn in production if no dedicated JWT secret key is configured
      config.after_initialize do
        next unless Rails.env.production?

        if Spree::Api::Config[:jwt_secret_key].blank? &&
           Rails.application.credentials.jwt_secret_key.blank? &&
           ENV['JWT_SECRET_KEY'].blank?
          Rails.logger.warn(
            '[Spree] No dedicated JWT secret key configured. Falling back to Rails.application.secret_key_base. ' \
            'Set Spree::Api::Config[:jwt_secret_key], Rails credentials jwt_secret_key, or ENV["JWT_SECRET_KEY"] ' \
            'for improved security.'
          )
        end
      end

      def self.root
        @root ||= Pathname.new(File.expand_path('../../..', __dir__))
      end
    end
  end
end
