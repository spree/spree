module Spree
  module Admin
    module OrdersHelper
      # Renders all the extension partials that may have been specified in the extensions
      def event_links
        links = []
        @order_events.sort.each do |event|
          if @order.send("can_#{event}?")
            links << button_link_to(Spree.t(event).capitalize, [event, :admin, @order],
                                    :method => :put,
                                    :icon => "#{event}",
                                    :data => { :confirm => Spree.t(:order_sure_want_to, :event => Spree.t(event)) })
          end
        end
        links.join(' ').html_safe
      end

      def line_item_shipment_price(line_item, quantity)
        Spree::Money.new(line_item.price * quantity, { currency: line_item.currency })
      end

      def avs_response_code
        {
          "A" => "Street address matches, but 5-digit and 9-digit postal code do not match.",
          "B" => "Street address matches, but postal code not verified.",
          "C" => "Street address and postal code do not match.",
          "D" => "Street address and postal code match. ",
          "E" => "AVS data is invalid or AVS is not allowed for this card type.",
          "F" => "Card member's name does not match, but billing postal code matches.",
          "G" => "Non-U.S. issuing bank does not support AVS.",
          "H" => "Card member's name does not match. Street address and postal code match.",
          "I" => "Address not verified.",
          "J" => "Card member's name, billing address, and postal code match.",
          "K" => "Card member's name matches but billing address and billing postal code do not match.",
          "L" => "Card member's name and billing postal code match, but billing address does not match.",
          "M" => "Street address and postal code match. ",
          "N" => "Street address and postal code do not match.",
          "O" => "Card member's name and billing address match, but billing postal code does not match.",
          "P" => "Postal code matches, but street address not verified.",
          "Q" => "Card member's name, billing address, and postal code match.",
          "R" => "System unavailable.",
          "S" => "Bank does not support AVS.",
          "T" => "Card member's name does not match, but street address matches.",
          "U" => "Address information unavailable. Returned if the U.S. bank does not support non-U.S. AVS or if the AVS in a U.S. bank is not functioning properly.",
          "V" => "Card member's name, billing address, and billing postal code match.",
          "W" => "Street address does not match, but 9-digit postal code matches.",
          "X" => "Street address and 9-digit postal code match.",
          "Y" => "Street address and 5-digit postal code match.",
          "Z" => "Street address does not match, but 5-digit postal code matches."
        }
      end

      def cvv_response_code
        {
          "M" => "CVV2 Match",
          "N" => "CVV2 No Match",
          "P" => "Not Processed",
          "S" => "Issuer indicates that CVV2 data should be present on the card, but the merchant has indicated data is not present on the card",
          "U" => "Issuer has not certified for CVV2 or Issuer has not provided Visa with the CVV2 encryption keys",
          ""  => "Transaction failed because wrong CVV2 number was entered or no CVV2 number was entered"
        }
      end
    end
  end
end
