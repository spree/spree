module Spree
  module Emails
    class LineItemSerializer < Spree::Api::V3::LineItemSerializer
      include Spree::Emails::PurchasedItemAttributes

      without_display_money

      many :option_values, resource: Spree::Emails::OptionValueSerializer

      typelize sku: [:string, nullable: true], amount: :string,
               url: [:string, nullable: true], image_url: [:string, nullable: true]

      attributes :sku

      # Price times quantity, before discounts — what the line cost.
      attribute :amount do |line_item|
        Spree::Money::Rounding.format(line_item.amount, line_item.currency)
      end

      # The full-size image; emails show the thumbnail in `image_url`.
      attributes :thumbnail_url, if: proc { false }
    end
  end
end
