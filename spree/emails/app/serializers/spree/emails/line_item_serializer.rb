module Spree
  module Emails
    class LineItemSerializer < Spree::Api::V3::LineItemSerializer
      include Spree::Emails::PurchasedItemAttributes

      # Price times quantity, before discounts — what the line cost.
      attribute :display_amount do |line_item|
        line_item.display_amount.to_s
      end
    end
  end
end
