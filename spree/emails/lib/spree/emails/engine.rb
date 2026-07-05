require 'rails/engine'

module Spree
  module Emails
    class Engine < Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_emails'

      # Add app/subscribers to autoload paths
      config.paths.add 'app/subscribers', eager_load: true

      # Register bundled ActionMailer previews so they show up at /rails/mailers
      # without the host app having to copy any files.
      initializer 'spree_emails.mailer_previews' do |app|
        if app.config.action_mailer.show_previews
          app.config.action_mailer.preview_paths << File.expand_path('previews', __dir__)
        end
      end

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
