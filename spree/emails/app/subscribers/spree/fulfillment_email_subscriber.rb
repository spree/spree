# frozen_string_literal: true

module Spree
  class FulfillmentEmailSubscriber < Spree::Subscriber
    # A customer who collected the order in person, or who already got a
    # download email, learns nothing from being told it was delivered.
    NO_DELIVERED_EMAIL_TYPES = %w[pickup digital].freeze

    subscribes_to 'fulfillment.fulfilled', 'fulfillment.delivered'

    on 'fulfillment.fulfilled', :send_fulfilled_email
    on 'fulfillment.delivered', :send_delivered_email

    private

    def send_fulfilled_email(event)
      fulfillment = notifiable_fulfillment(event)
      return unless fulfillment

      FulfillmentMailer.fulfilled_email(fulfillment.id).deliver_later
    end

    def send_delivered_email(event)
      fulfillment = notifiable_fulfillment(event)
      return unless fulfillment
      return if NO_DELIVERED_EMAIL_TYPES.include?(fulfillment.fulfillment_type)

      FulfillmentMailer.delivered_email(fulfillment.id).deliver_later
    end

    def notifiable_fulfillment(event)
      return unless notify_customer?(event)

      fulfillment = Spree::Fulfillment.find_by_prefix_id(event.payload['id'])
      fulfillment if fulfillment&.store&.prefers_send_consumer_transactional_emails?
    end

    # An admin can suppress the email for one transition (a correction, a
    # re-ship, goods handed over in person). Absent metadata means send, so
    # events published by anything unaware of the flag keep the historic
    # behavior.
    def notify_customer?(event)
      event.metadata.fetch('notify_customer', true) != false
    end
  end
end
