# frozen_string_literal: true

module Spree
  module Admin
    module WebhookEndpointsHelper
      def available_webhook_events
        @available_webhook_events ||= begin
          events = []

          # Add lifecycle events from eventable models
          Spree.eventable_models.each do |model_class|
            base_name = model_class.name.demodulize.underscore
            events << "#{base_name}.created"
            events << "#{base_name}.updated"
            events << "#{base_name}.deleted"
          end

          # Add custom events
          events += custom_webhook_events

          events.sort.uniq
        end
      end

      def webhook_delivery_status_badge(delivery)
        if delivery.pending?
          content_tag(:span, Spree.t(:pending), class: 'badge badge-light')
        elsif delivery.successful?
          content_tag(:span, Spree.t(:success), class: 'badge badge-success')
        else
          content_tag(:span, Spree.t('state_machine_states.failed'), class: 'badge badge-danger')
        end
      end

      def webhook_endpoint_success_percentage(webhook_endpoint)
        return '' if webhook_endpoint.webhook_deliveries.none?

        (webhook_endpoint.webhook_deliveries.successful.count / webhook_endpoint.webhook_deliveries.count.to_f * 100).round(2)
      end

      private

      def custom_webhook_events
        %w[
          order.completed
          order.paid
          order.canceled
          order.resumed
          order.shipped
          payment.paid
          payment.voided
          shipment.shipped
          product.activated
          product.archived
          product.drafted
          product.back_in_stock
          product.out_of_stock
        ]
      end
    end
  end
end
