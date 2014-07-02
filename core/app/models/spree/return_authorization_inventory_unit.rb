module Spree
  class ReturnAuthorizationInventoryUnit < Spree::Base
    belongs_to :return_authorization, inverse_of: :return_authorization_inventory_units
    belongs_to :inventory_unit, inverse_of: :return_authorization_inventory_units
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

    private

    def stock_item
      Spree::StockItem.find_by({
        variant_id: inventory_unit.variant_id,
        stock_location_id: return_authorization.stock_location_id,
      })
    end
  end
end
