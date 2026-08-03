module Spree
  module FulfillmentHelper
    def fulfillment_tracking_link_to(fulfillment:, name: nil, html_options: {})
      tracking_url = fulfillment.tracking_url.presence
      return '' unless tracking_url

      display_text = name || fulfillment.tracking.presence || tracking_url

      link_to display_text, tracking_url, html_options
    end
  end
end
