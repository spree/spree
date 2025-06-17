module Spree
  module ShipmentHelper
    include BaseHelper

    def shipment_tracking_link_to(shipment, options = nil)
      display_text = shipment.tracking.presence || shipment.tracking_url

      link_to display_text, shipment.tracking_url, options
    end
  end
end