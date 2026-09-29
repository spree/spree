module Spree
  module Emails
    # One line as it travels in one parcel. A line packed from two warehouses
    # rides in two parcels, so the quantity and amount are the parcel's share
    # rather than the whole line's.
    class ParcelItemSerializer < Spree::Emails::BaseSerializer
      include Spree::Emails::PurchasedItemAttributes

      attribute :id do |item|
        item.line_item.prefixed_id
      end

      attribute :name do |item|
        item.line_item.name
      end

      attributes :quantity

      attribute :display_price do |item|
        item.line_item.display_price.to_s
      end

      attribute :display_amount do |item|
        Spree::Money.new(item.line_item.price * item.quantity, currency: item.line_item.currency).to_s
      end
    end
  end
end
