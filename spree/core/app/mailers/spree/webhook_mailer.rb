# frozen_string_literal: true

module Spree
  class WebhookMailer < BaseMailer
    def endpoint_disabled(webhook_endpoint)
      @endpoint = webhook_endpoint
      @current_store = webhook_endpoint.store

      with_store_locale(webhook_endpoint.store) do
        mail_template(
          { endpoint: email_data(@endpoint, Spree::Emails::WebhookEndpointSerializer) },
          to: @current_store.new_order_notifications_email.presence || @current_store.mail_from_address,
          store_url: @current_store.formatted_url
        )
      end
    end
  end
end
