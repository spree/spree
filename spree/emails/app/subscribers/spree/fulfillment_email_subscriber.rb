# frozen_string_literal: true

module Spree
  class FulfillmentEmailSubscriber < Spree::Subscriber
    subscribes_to 'fulfillment.fulfilled'

    def handle(event)
      fulfillment = find_fulfillment(event)
      return unless fulfillment

      store = fulfillment.store
      return unless store.prefers_send_consumer_transactional_emails?

      FulfillmentMailer.fulfilled_email(fulfillment.id).deliver_later
    end

    private

    def find_fulfillment(event)
      fulfillment_id = event.payload['id']
      Spree::Fulfillment.find_by_prefix_id(fulfillment_id)
    end
  end
end
