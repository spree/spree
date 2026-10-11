module Spree
  module Api
    module V3
      module Admin
        # What the email template preview and test email endpoints render.
        # Not published on its own: both declare it as `EmailTemplatePreviewParams`.
        class EmailTemplatePreviewRequestSchema < Spree::Api::V3::Admin::EmailTemplateLanguageRequestSchema
          string :subject, nullable: true, example: 'Your order {{ order.number }} is confirmed',
                           description: 'An unsaved subject, in place of the current one.'
          string :body, example: '<mj-section><mj-column><mj-text>Thanks, {{ order.customer_name }}!</mj-text></mj-column></mj-section>',
                        description: 'An unsaved body, in place of the current one.'
          id :record_id, example: 'or_m3Rp9wXz',
                         description: "The record to build sample data from; the store's latest matching record otherwise."
          string :email_key, permit: false, example: 'spree.order_mailer.confirm_email',
                             description: 'For the layout or a partial, the email to show it in.'
          object :branding, permit: false,
                            description: "Unsaved colors and font to preview, named like the store's `email_*` settings." do
            string(*Spree::Emails::Branding::COLORS, nullable: true)
            string :font, nullable: true, enum: Spree::Emails::Branding::FONTS.keys
          end
        end
      end
    end
  end
end
