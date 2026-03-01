# frozen_string_literal: true

module Spree
  class OrderEmailSubscriber < Spree::Subscriber
    subscribes_to 'order.completed', 'order.canceled', 'order.resend_confirmation_email'

    on 'order.completed', :send_confirmation_email
    on 'order.canceled', :send_cancel_email
    on 'order.resend_confirmation_email', :resend_confirmation_email

    private

    def send_confirmation_email(event)
      order = find_order(event)
      return unless order
      return if order.confirmation_delivered?

      store = order.store
      return unless store.prefers_send_consumer_transactional_emails?

      OrderMailer.confirm_email(order.id).deliver_later
      order.update_column(:confirmation_delivered, true)

      send_store_owner_notification(order) if should_notify_store_owner?(order)
    end

    def resend_confirmation_email(event)
      order = find_order(event)
      return unless order

      store = order.store
      return unless store.prefers_send_consumer_transactional_emails?

      OrderMailer.confirm_email(order.id).deliver_later
      order.update_column(:confirmation_delivered, true)
    end

    def send_cancel_email(event)
      order = find_order(event)
      return unless order

      OrderMailer.cancel_email(order.id).deliver_later
    end

    def send_store_owner_notification(order)
      return if order.store_owner_notification_delivered?
      return if order.store.new_order_notifications_email.blank?

      OrderMailer.store_owner_notification_email(order.id).deliver_later
      order.update_column(:store_owner_notification_delivered, true)
    end

    def should_notify_store_owner?(order)
      order.store.new_order_notifications_email.present? &&
        !order.store_owner_notification_delivered?
    end

    def find_order(event)
      order_id = event.payload['id']
      Spree::Order.find_by_prefix_id(order_id)
    end
  end
end
