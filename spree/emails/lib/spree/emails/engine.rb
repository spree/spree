require 'rails/engine'

module Spree
  module Emails
    class Engine < Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_emails'

      # Add app/subscribers to autoload paths
      config.paths.add 'app/subscribers', eager_load: true

      # Add email event subscribers
      config.after_initialize do
        Spree.subscribers.concat [
          Spree::OrderEmailSubscriber,
          Spree::ShipmentEmailSubscriber,
          Spree::ReimbursementEmailSubscriber,
          Spree::NewsletterSubscriberEmailSubscriber
        ]
      end
    end
  end
end
