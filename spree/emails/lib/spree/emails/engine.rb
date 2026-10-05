require 'rails/engine'

module Spree
  module Emails
    class Engine < Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_emails'

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
          Spree::OrderGroupEmailSubscriber,
          Spree::FulfillmentEmailSubscriber,
          Spree::ReturnEmailSubscriber,
          Spree::NewsletterSubscriberEmailSubscriber,
          Spree::CustomerEmailSubscriber,
          Spree::DataRequestEmailSubscriber,
          Spree::CompanyEmailSubscriber,
          Spree::DigitalAssetEmailSubscriber,
          Spree::SellerEmailSubscriber
        ]
      end
    end
  end
end
