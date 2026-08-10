# frozen_string_literal: true

module Spree
  class DigitalAssetEmailSubscriber < Spree::Subscriber
    # Links are created during completion, before order.placed fires, so the
    # order already knows everything the email needs.
    subscribes_to 'order.placed', 'order.resend_digital_links_email'

    on 'order.placed', :send_files_ready_email
    on 'order.resend_digital_links_email', :resend_files_ready_email

    private

    def send_files_ready_email(event)
      deliver(event)
    end

    def resend_files_ready_email(event)
      deliver(event, resend: true)
    end

    def deliver(event, resend: false)
      order = find_order(event)
      return unless order
      return if order.digital_links.empty?
      return unless order.store.prefers_send_consumer_transactional_emails?

      DigitalAssetMailer.files_ready_email(order.id, resend).deliver_later
    end

    def find_order(event)
      Spree::Order.find_by_prefix_id(event.payload['id'])
    end
  end
end
