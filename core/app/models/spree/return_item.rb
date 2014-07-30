module Spree
  class ReturnItem < Spree::Base
    class_attribute :return_eligibility_validator
    self.return_eligibility_validator = ReturnItem::ReturnEligibilityValidator

    belongs_to :return_authorization, inverse_of: :return_items
    belongs_to :inventory_unit, inverse_of: :return_items
    belongs_to :exchange_variant, class: 'Spree::Variant'
    belongs_to :customer_return, inverse_of: :return_items

    validate :belongs_to_same_customer_order
    validates :inventory_unit, presence: true, uniqueness: {scope: :return_authorization}

    scope :awaiting_return, -> { where(reception_status: 'awaiting') }
    scope :not_cancelled, -> { where.not(reception_status: 'cancelled') }

    serialize :acceptance_status_errors

    delegate :eligible_for_return?, :requires_manual_intervention?, to: :validator

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
      event :attempt_accept do
        transition to: :accepted, from: :not_received, if: -> (return_item) { return_item.eligible_for_return? }
        transition to: :manual_intervention_required, from: :not_received, if: -> (return_item) { return_item.requires_manual_intervention? }
        transition to: :rejected, from: :not_received
      end

      # bypasses eligibility checks
      event :accept do
        transition to: :accepted, from: [:not_received, :manual_intervention_required]
      end

      # bypasses eligibility checks
      event :reject do
        transition to: :rejected, from: [:not_received, :manual_intervention_required]
      end

      # bypasses eligibility checks
      event :require_manual_intervention do
        transition to: :manual_intervention_required, from: :not_received
      end

      after_transition any => any, :do => :persist_acceptance_status_errors
    end

    def display_pre_tax_amount
      Spree::Money.new(pre_tax_amount, { currency: currency })
    end

    private

    def persist_acceptance_status_errors
      self.update_attributes(acceptance_status_errors: validator.errors)
    end

    def stock_item
      return unless customer_return

      Spree::StockItem.find_by({
        variant_id: inventory_unit.variant_id,
        stock_location_id: customer_return.stock_location_id,
      })
    end

    def currency
      return_authorization.try(:currency) || Spree::Config[:currency]
    end

    def process_inventory_units!
      inventory_unit.return!

      if inventory_unit.variant.should_track_inventory? && stock_item
        Spree::StockMovement.create!(stock_item_id: stock_item.id, quantity: 1)
      end
    end

    # This logic is also present in the customer return. The reason for the
    # duplication and not having a validates_associated on the customer_return
    # is that it would lead to duplicate error messages for the customer return.
    # Not specifying a stock location for example would add an error message about
    # the mandatory field when validating the customer return and again when saving
    # the associated return items.
    def belongs_to_same_customer_order
      return unless customer_return && inventory_unit

      if customer_return.order_id != inventory_unit.order_id
        errors.add(:base, Spree.t(:return_items_cannot_be_associated_with_multiple_orders))
      end
    end

    def validator
      @validator ||= return_eligibility_validator.new(self)
    end
  end
end
