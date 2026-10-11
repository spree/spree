module Spree
  module Api
    module V3
      module Admin
        # What the email template preview and test email endpoints render.
        # Not published on its own: both declare it as `EmailTemplatePreviewParams`.
        class EmailTemplatePreviewRequestSchema < Spree::Api::V3::Admin::EmailTemplateLanguageRequestSchema
          attribute :subject, :string,
            nullable: true,
            example: 'Your order {{ order.number }} is confirmed',
            description: 'An unsaved subject, in place of the current one.'
          attribute :body, :string,
            example: '<mj-section><mj-column><mj-text>Thanks, {{ order.customer_name }}!</mj-text></mj-column></mj-section>',
            description: 'An unsaved body, in place of the current one.'
          attribute :record_id, :id,
            example: 'or_m3Rp9wXz',
            description: "The record to build sample data from; the store's latest matching record otherwise."
          attribute :email_key, :string,
            permit: false,
            example: 'spree.order_mailer.confirm_email',
            description: 'For the layout or a partial, the email to show it in.'
          attribute :branding, :object,
            permit: false,
            description: "Unsaved colors and font to preview, named like the store's `email_*` settings." do |branding|
            Spree::Emails::Branding::COLORS.each { |name| branding.attribute name, :string, nullable: true }
            branding.attribute :font, :string, nullable: true, choices: Spree::Emails::Branding::FONTS.keys
          end
        end
      end
    end
  end
end
