module Spree
  module Emails
    class LineItemSerializer < Spree::Api::V3::LineItemSerializer
      include Spree::Emails::PurchasedItemAttributes

      attributes :sku

      # Price times quantity, before discounts — what the line cost.
      attribute :display_amount do |line_item|
        line_item.display_amount.to_s
      end

      # The full-size image; emails show the thumbnail in `image_url`.
      attributes :thumbnail_url, if: proc { false }
    end
  end
end
