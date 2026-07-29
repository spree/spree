module Spree
  # Deprecated: use Spree::FulfillmentHelper. Removed in Spree 6.1.
  module ShipmentHelper
    include Spree::FulfillmentHelper

    def shipment_tracking_link_to(shipment:, name: nil, html_options: {})
      Spree::Deprecation.warn('shipment_tracking_link_to is deprecated and will be removed in Spree 6.1. Use fulfillment_tracking_link_to instead.')
      fulfillment_tracking_link_to(fulfillment: shipment, name: name, html_options: html_options)
    end
  end
end
