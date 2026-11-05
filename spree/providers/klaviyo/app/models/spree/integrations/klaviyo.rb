module Spree
  module Integrations
    # Per-store Klaviyo connection. The class and preference names are the
    # 1.x gem's, kept because upgraded stores have them stored.
    class Klaviyo < Spree::Integration
      # Klaviyo runs the whole double opt-in itself, so Spree's confirmation
      # (and its token) is never sent while the integration is active.
      NEWSLETTER_CONFIRMATION = 'spree/newsletter_mailer/email_confirmation'.freeze

      # Each switch hands Klaviyo the emails whose flow is triggered by the
      # event sent exactly when Spree would have sent them.
      REPLACED_EMAILS_BY_SWITCH = {
        sends_order_confirmation: %w[spree/order_mailer/confirm_email spree/order_group_mailer/confirm_email],
        sends_order_cancellation: %w[spree/order_mailer/cancel_email],
        sends_shipping_confirmation: %w[spree/fulfillment_mailer/fulfilled_email],
        sends_refund_confirmation: %w[spree/return_mailer/refunded_email]
      }.freeze

      preference :klaviyo_private_api_key, :password
      preference :default_newsletter_list_id, :string

      preference :sends_order_confirmation, :boolean, default: false
      preference :sends_order_cancellation, :boolean, default: false
      preference :sends_shipping_confirmation, :boolean, default: false
      preference :sends_refund_confirmation, :boolean, default: false
      # Sends the customer's database id as the profile's external_id, the
      # value 1.x sent, so profiles 1.x created keep matching.
      preference :use_database_ids_as_external_ids, :boolean, default: false

      def self.integration_group
        'marketing'
      end

      def self.logo_url
        'https://spreecommerce.org/docs/images/integrations/logos/klaviyo.png'
      end

      def self.docs_url
        'https://spreecommerce.org/docs/integrations/marketing/klaviyo'
      end

      # Fallback for hosts without the gem's translations; the localized
      # description in config/locales wins.
      def self.description
        'Customer profiles, newsletter sign-ups and order events in Klaviyo, for flows, segments and campaigns.'
      end

      # @return [Array<String>]
      def replaced_customer_emails
        REPLACED_EMAILS_BY_SWITCH.each_with_object([NEWSLETTER_CONFIRMATION]) do |(switch, keys), emails|
          emails.concat(keys) if public_send(:"preferred_#{switch}")
        end
      end
    end
  end
end
