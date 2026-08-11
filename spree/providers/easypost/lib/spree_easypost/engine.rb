require 'rails/engine'

module SpreeEasyPost
  class Engine < Rails::Engine
    engine_name 'spree_easypost'

    # Gem name and module disagree on word boundaries (spree_easypost →
    # SpreeEasyPost, matching the official EasyPost SDK's casing), so
    # Zeitwerk needs telling once.
    initializer 'spree_easypost.inflections', before: :set_autoload_paths do
      Rails.autoloaders.each do |autoloader|
        autoloader.inflector.inflect('spree_easypost' => 'SpreeEasyPost')
      end
    end

    # The gem ships one route (the tracker webhook), so it is appended rather
    # than asking hosts to mount an engine for a single endpoint.
    initializer 'spree_easypost.routes' do |app|
      app.routes.append do
        # Routed to the class rather than a 'spree_easypost/webhooks' string:
        # Rails camelizes that to SpreeEasypost, which is not what the gem's
        # module is called (see the inflection above).
        post '/spree_easypost/webhooks',
             to: SpreeEasyPost::WebhooksController.action(:create),
             as: :spree_easypost_webhooks
      end
    end

    config.after_initialize do
      Spree.integrations << 'SpreeEasyPost::Integration'
      Spree.delivery_rate_providers << SpreeEasyPost::DeliveryRateProvider
      Spree.fulfillment_providers << SpreeEasyPost::FulfillmentProvider
    end
  end
end
