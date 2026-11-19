module Spree
  module Emails
    # One line as it travels in one parcel. A line packed from two warehouses
    # rides in two parcels, so the quantity and amount are the parcel's share
    # rather than the whole line's.
    #
    # The parcel's units name what is in the box: an exchange ships its
    # replacement against the original line item, so the line item's variant
    # is not always the one sent.
    class ParcelItemSerializer < Spree::Emails::BaseSerializer
      include Spree::Emails::PurchasedItemAttributes

      attribute :id do |item|
        item.line_item.prefixed_id
      end

      attribute :name do |item|
        purchased_variant(item).name
      end

      attributes :quantity

      attribute :sku do |item|
        purchased_variant(item).sku
      end

      attribute :options_text do |item|
        purchased_variant(item).options_text
      end

      attribute :price do |item|
        Spree::Money::Rounding.format(item.line_item.price, item.line_item.currency, unit_price: true)
      end

      attribute :amount do |item|
        Spree::Money::Rounding.format(item.line_item.price * item.quantity, item.line_item.currency)
      end
    end
  end
end
