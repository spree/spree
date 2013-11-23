module Spree
  module Admin
    module OrdersHelper
      # Renders all the extension partials that may have been specified in the extensions
      def event_links
        links = []
        @order_events.sort.each do |event|
          if @order.send("can_#{event}?")
            links << button_link_to(Spree.t(event), fire_admin_order_url(@order, :e => event),
                                    :method => :put,
                                    :icon => "icon-#{event}",
                                    :data => { :confirm => Spree.t(:order_sure_want_to, :event => Spree.t(event)) })
          end
        end
        links.join('&nbsp;').html_safe
      end

      def line_item_shipment_price(line_item, quantity)
        Spree::Money.new(line_item.price * quantity, { currency: line_item.currency })
      end

      def avs_response_code
        {
          a: "Street address matches, but 5-digit and 9-digit postal code do not match.",
          b: "Street address matches, but postal code not verified.",
          c: "Street address and postal code do not match.",
          d: "Street address and postal code match. Code \"M\" is equivalent.",
          e: "AVS data is invalid or AVS is not allowed for this card type.",
          f: "Card member's name does not match, but billing postal code matches.",
          g: "Non-U.S. issuing bank does not support AVS.",
          h: "Card member's name does not match. Street address and postal code match.",
          i: "Address not verified.",
          j: "Card member's name, billing address, and postal code match.",
          k: "Card member's name matches but billing address and billing postal code do not match.",
          l: "Card member's name and billing postal code match, but billing address does not match.",
          m: "Street address and postal code match. Code \"D\" is equivalent.",
          n: "Street address and postal code do not match.",
          o: "Card member's name and billing address match, but billing postal code does not match.",
          p: "Postal code matches, but street address not verified.",
          q: "Card member's name, billing address, and postal code match.",
          r: "System unavailable.",
          s: "Bank does not support AVS.",
          t: "Card member's name does not match, but street address matches.",
          u: "Address information unavailable. Returned if the U.S. bank does not support non-U.S. AVS or if the AVS in a U.S. bank is not functioning properly.",
          v: "Card member's name, billing address, and billing postal code match.",
          w: "Street address does not match, but 9-digit postal code matches.",
          x: "Street address and 9-digit postal code match.",
          y: "Street address and 5-digit postal code match.",
          z: "Street address does not match, but 5-digit postal code matches."
        }
      end
    end
  end
end
