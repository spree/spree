require 'rails/engine'

module SpreeOpenTelemetry
  class Engine < Rails::Engine
    engine_name 'spree_opentelemetry'

    # After the host's initializers so a SpreeOpenTelemetry.configure block
    # is applied before the SDK boots.
    initializer 'spree_opentelemetry.install', after: :load_config_initializers do
      SpreeOpenTelemetry.install!
    end

    # DeliverWebhook is reloadable — its decorator list resets with the class
    # on every code reload, so registration must happen in to_prepare.
    config.to_prepare do
      if SpreeOpenTelemetry.installed? && defined?(Spree::Webhooks::DeliverWebhook)
        decorators = Spree::Webhooks::DeliverWebhook.header_decorators
        decorators << SpreeOpenTelemetry::WebhookTracePropagation unless decorators.include?(SpreeOpenTelemetry::WebhookTracePropagation)
      end
    end
  end
end
