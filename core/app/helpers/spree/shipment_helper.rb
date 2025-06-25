module Spree
  module ShipmentHelper
    include BaseHelper

    def shipment_tracking_link_to(shipment, options = nil)
      tracking_url = shipment.tracking_url.presence
      return '' unless tracking_url

      display_text = shipment.tracking.presence || tracking_url

      link_to display_text, tracking_url, options
    end
  end
end
