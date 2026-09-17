# frozen_string_literal: true

module Spree
  # The confirmation for a checkout that produced more than one order.
  #
  # Its child orders place silently (+Spree::Carts::Complete#complete_orders+),
  # because none of them is the purchase — this is what tells the customer what
  # they bought, what they paid and how it arrives.
  class OrderGroupEmailSubscriber < Spree::Subscriber
    subscribes_to 'order_group.completed', 'order_group.resend_confirmation_email'

    on 'order_group.completed', :send_confirmation_email
    on 'order_group.resend_confirmation_email', :resend_confirmation_email

    private

    def send_confirmation_email(event)
      order_group = find_order_group(event)
      return unless order_group
      return unless order_group.store.prefers_send_consumer_transactional_emails?

      # Completion is replayable, and a resumed finalize re-publishes this
      # event. Each email is guarded by its own flag rather than the method
      # returning on the first: a replay that has already confirmed the
      # customer may still owe the operator their notification.
      unless order_group.confirmation_delivered?
        OrderGroupMailer.confirm_email(order_group.id).deliver_later
        order_group.update_column(:confirmation_delivered, true)
      end

      send_store_owner_notification(order_group)
    end

    def resend_confirmation_email(event)
      order_group = find_order_group(event)
      return unless order_group
      return unless order_group.store.prefers_send_consumer_transactional_emails?

      OrderGroupMailer.confirm_email(order_group.id, true).deliver_later
      order_group.update_column(:confirmation_delivered, true)
    end

    # One notification per purchase, like the customer's. Told about the
    # checkout rather than about each seller's share of it, because that is
    # what happened.
    def send_store_owner_notification(order_group)
      return if order_group.store_owner_notification_delivered?
      return if order_group.store.new_order_notifications_email.blank?

      OrderGroupMailer.store_owner_notification_email(order_group.id).deliver_later
      order_group.update_column(:store_owner_notification_delivered, true)
    end

    def find_order_group(event)
      Spree::OrderGroup.find_by_prefix_id(event.payload['id'])
    end
  end
end
