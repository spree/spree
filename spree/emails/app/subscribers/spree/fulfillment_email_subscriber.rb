# frozen_string_literal: true

module Spree
  class FulfillmentEmailSubscriber < Spree::Subscriber
    subscribes_to 'fulfillment.fulfilled'

    def handle(event)
      return unless notify_customer?(event)

      fulfillment = find_fulfillment(event)
      return unless fulfillment

      store = fulfillment.store
      return unless store.prefers_send_consumer_transactional_emails?

      FulfillmentMailer.fulfilled_email(fulfillment.id).deliver_later
    end

    private

    # An admin shipping from the backoffice can suppress the shipment email for
    # this one dispatch (a correction, a re-ship, goods handed over in person).
    # Absent metadata means send, so events published by anything unaware of
    # the flag keep the historic behavior.
    def notify_customer?(event)
      event.metadata.fetch('notify_customer', true) != false
    end

    def find_fulfillment(event)
      fulfillment_id = event.payload['id']
      Spree::Fulfillment.find_by_prefix_id(fulfillment_id)
    end
  end
end
