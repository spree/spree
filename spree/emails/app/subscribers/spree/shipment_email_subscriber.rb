# frozen_string_literal: true

module Spree
  class ShipmentEmailSubscriber < Spree::Subscriber
    subscribes_to 'shipment.shipped'

    def handle(event)
      shipment = find_shipment(event)
      return unless shipment

      store = shipment.store
      return unless store.prefers_send_consumer_transactional_emails?

      ShipmentMailer.shipped_email(shipment.id).deliver_later
    end

    private

    def find_shipment(event)
      shipment_id = event.payload['id']
      Spree::Shipment.find_by_prefix_id(shipment_id)
    end
  end
end
