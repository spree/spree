module Spree
  class ReimbursementItem < ActiveRecord::Base
    belongs_to :reimbursement, inverse_of: :reimbursement_items
    belongs_to :inventory_unit, inverse_of: :reimbursement_items
    belongs_to :return_item, inverse_of: :reimbursement_item

    belongs_to :exchange_variant, class_name: 'Spree::Variant'
    belongs_to :exchange_inventory_unit, class_name: 'Spree::InventoryUnit', inverse_of: :original_reimbursement_item

    belongs_to :override_reimbursement_type, class_name: 'Spree::ReimbursementType'

    before_save :set_exchange_pre_tax_amount

    delegate :variant, to: :inventory_unit

    def total
      pre_tax_amount + additional_tax_total
    end

    def display_total
      Spree::Money.new(total, currency: currency)
    end

    def display_pre_tax_amount
      Spree::Money.new(pre_tax_amount, currency: currency)
    end

    def currency
      reimbursement.currency
    end

    def build_exchange_inventory_unit
      # The inventory unit needs to have the new variant
      # but it also needs to know the original line item
      # for pricing information for if the inventory unit is
      # ever returned. This means that the inventory unit's line_item
      # will have a different variant than the inventory unit itself
      super(variant: exchange_variant, line_item: inventory_unit.line_item) if exchange_required?
    end

    def exchange_required?
      exchange_requested? && !exchange_processed?
    end

    def exchange_requested?
      exchange_variant.present?
    end

    def exchange_processed?
      exchange_inventory_unit.present?
    end

    def eligible_exchange_variants
      Spree::ReturnItem.exchange_variant_engine.eligible_variants(variant)
    end

    private

    def set_exchange_pre_tax_amount
      self.pre_tax_amount = 0.0.to_d if exchange_requested?
    end

  end
end
