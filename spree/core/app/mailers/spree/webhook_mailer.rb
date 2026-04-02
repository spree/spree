# frozen_string_literal: true

module Spree
  class WebhookMailer < BaseMailer
    def endpoint_disabled(webhook_endpoint)
      @endpoint = webhook_endpoint
      @current_store = webhook_endpoint.store

      mail(
        to: @current_store.new_order_notifications_email.presence || @current_store.mail_from_address,
        from: from_address,
        subject: Spree.t('webhook_mailer.endpoint_disabled.subject', endpoint_name: @endpoint.name || @endpoint.url),
        store_url: @current_store.formatted_url
      )
    end
  end
end
