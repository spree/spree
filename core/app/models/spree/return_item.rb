module Spree
  class ReturnItem < Spree::Base
    belongs_to :return_authorization, inverse_of: :return_items
    belongs_to :inventory_unit, inverse_of: :return_items
    belongs_to :exchange_variant, class: 'Spree::Variant'

    validates :return_authorization, presence: true
    validates :inventory_unit, presence: true, uniqueness: {scope: :return_authorization}

    scope :received, -> { where.not(received_at: nil) }

    def receive!
      update_attributes!(received_at: Time.now)

      inventory_unit.return!

      if inventory_unit.variant.should_track_inventory? && stock_item
        Spree::StockMovement.create!(stock_item_id: stock_item.id, quantity: 1)
      end
    end

    def display_pre_tax_amount
      Spree::Money.new(pre_tax_amount, { currency: currency })
    end

    private

    def stock_item
      Spree::StockItem.find_by({
        variant_id: inventory_unit.variant_id,
        stock_location_id: return_authorization.stock_location_id,
      })
    end

    def currency
      return_authorization.try(:currency) || Spree::Config[:currency]
    end
  end
end
