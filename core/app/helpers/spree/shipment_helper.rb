module Spree
  module ShipmentHelper
    def shipment_tracking_link_to(shipment:, name: nil, html_options: {})
      tracking_url = shipment.tracking_url.presence
      return '' unless tracking_url

      display_text = name || shipment.tracking.presence || tracking_url

      link_to display_text, tracking_url, html_options
    end
  end
end
