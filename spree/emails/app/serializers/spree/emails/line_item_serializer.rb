module Spree
  module Emails
    class LineItemSerializer < Spree::Api::V3::LineItemSerializer
      _attributes.delete(:custom_fields)

      include Spree::Emails::PurchasedItemAttributes

      without_display_money

      many :option_values, resource: Spree::Emails::OptionValueSerializer
      one :gift_card_recipient, key: :recipient, resource: Spree::Emails::GiftCardRecipientSerializer,
                                source: proc { gift_card_recipient if gift_card? }
      many :gift_cards, resource: Spree::Emails::GiftCardSerializer, params: { hide_credentials: true },
                        source: proc { gift_card? ? gift_cards : [] },
                        if: proc { |line_item| line_item.order_id.present? }

      typelize sku: [:string, { nullable: true }], amount: :string,
               url: [:string, { nullable: true }], image_url: [:string, { nullable: true }]

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
