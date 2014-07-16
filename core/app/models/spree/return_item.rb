module Spree
  class ReturnItem < Spree::Base
    belongs_to :return_authorization, inverse_of: :return_items
    belongs_to :inventory_unit, inverse_of: :return_items
    belongs_to :exchange_variant, class: 'Spree::Variant'

    validates :return_authorization, presence: true
    validates :inventory_unit, presence: true, uniqueness: {scope: :return_authorization}

    state_machine :reception_status, initial: :awaiting do
      before_transition to: :received, do: :process_inventory_units!

      event :receive do
        transition to: :received, from: :awaiting
      end

      event :cancel do
        transition to: :cancelled, from: :awaiting
      end

      event :give do
        transition to: :given_to_customer, from: :awaiting
      end

    end

    state_machine :acceptance_status, initial: :not_received do

      event :accept do
        transition to: :accepted, from: :not_received
      end

      event :reject do
        transition to: :rejected, from: :not_received
      end

      event :require_manual_intervention do
        transition to: :manual_intervention_required, from: :not_received
      end

    end

    def process_inventory_units!
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
