require 'rails/engine'

module Spree
  module Emails
    class Engine < Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_emails'

      # Add app/subscribers to autoload paths
      config.paths.add 'app/subscribers', eager_load: true

      # Register email subscribers after initialization
      config.after_initialize do
        Spree::OrderEmailSubscriber.register!
        Spree::ShipmentEmailSubscriber.register!
        Spree::ReimbursementEmailSubscriber.register!
      end
    end
  end
end
