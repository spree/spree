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

      # The customer emails merchants may edit in the dashboard, with the layout
      # and shared partials they are built from. Staff, store-owner and seller
      # emails are deliberately not registered.
      initializer 'spree_emails.editable_templates' do
        {
          'spree/order_mailer/confirm_email' => 'Spree::Emails::Samples::Order',
          'spree/order_mailer/cancel_email' => 'Spree::Emails::Samples::Order',
          'spree/order_mailer/payment_link_email' => 'Spree::Emails::Samples::PaymentLink',
          'spree/order_group_mailer/confirm_email' => 'Spree::Emails::Samples::OrderGroup',
          'spree/fulfillment_mailer/fulfilled_email' => 'Spree::Emails::Samples::Fulfillment',
          'spree/return_mailer/refunded_email' => 'Spree::Emails::Samples::Return',
          'spree/digital_asset_mailer/files_ready_email' => 'Spree::Emails::Samples::Downloads',
          'spree/customer_mailer/password_reset_email' => 'Spree::Emails::Samples::PasswordReset',
          'spree/customer_mailer/data_export_email' => 'Spree::Emails::Samples::DataExport',
          'spree/newsletter_mailer/email_confirmation' => 'Spree::Emails::Samples::NewsletterConfirmation',
          'spree/company_mailer/invitation_email' => 'Spree::Emails::Samples::CompanyInvitation'
        }.each { |key, sample| Spree.editable_email_templates.register(key, kind: :email, sample: sample) }

        Spree.editable_email_templates.register('layouts/spree/base_mailer', kind: :layout)
        %w[line_item order_summary purchase_totals fulfillment_group summary_row].each do |partial|
          Spree.editable_email_templates.register("spree/shared/#{partial}", kind: :partial)
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
