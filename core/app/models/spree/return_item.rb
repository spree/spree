module Spree
  class ReturnItem < Spree::Base
    COMPLETED_RECEPTION_STATUSES = %w(received given_to_customer)

    class_attribute :return_eligibility_validator
    self.return_eligibility_validator = ReturnItem::EligibilityValidator::Default

    def return_quantity=(value)
      @_return_quantity = value.to_i
    end

    def return_quantity
      @_return_quantity.nil? ? inventory_unit.quantity : @_return_quantity
    end

    class_attribute :exchange_variant_engine
    self.exchange_variant_engine = ReturnItem::ExchangeVariantEligibility::SameProduct

    class_attribute :refund_amount_calculator
    self.refund_amount_calculator = Calculator::Returns::DefaultRefundAmount

    with_options inverse_of: :return_items do
      belongs_to :return_authorization
      belongs_to :inventory_unit
      belongs_to :customer_return
      belongs_to :reimbursement
    end
    has_many :exchange_inventory_units, class_name: 'Spree::InventoryUnit',
                                        foreign_key: :original_return_item_id,
                                        inverse_of: :original_return_item
    belongs_to :exchange_variant, class_name: 'Spree::Variant'
    belongs_to :preferred_reimbursement_type, class_name: 'Spree::ReimbursementType'
    belongs_to :override_reimbursement_type, class_name: 'Spree::ReimbursementType'

    validate :eligible_exchange_variant
    validate :belongs_to_same_customer_order
    validate :validate_acceptance_status_for_reimbursement
    validates :inventory_unit, presence: true
    validate :validate_no_other_completed_return_items, on: :create
    validates :return_quantity, numericality: { greater_than_or_equal_to: 1 }
    validate :sufficient_quantity_for_return

    after_create :cancel_others, unless: :cancelled?

    scope :awaiting_return, -> { where(reception_status: 'awaiting') }
    scope :received, -> { where(reception_status: 'received') }
    scope :not_cancelled, -> { where.not(reception_status: 'cancelled') }
    scope :pending, -> { where(acceptance_status: 'pending') }
    scope :accepted, -> { where(acceptance_status: 'accepted') }
    scope :rejected, -> { where(acceptance_status: 'rejected') }
    scope :manual_intervention_required, -> { where(acceptance_status: 'manual_intervention_required') }
    scope :undecided, -> { where(acceptance_status: %w(pending manual_intervention_required)) }
    scope :decided, -> { where.not(acceptance_status: %w(pending manual_intervention_required)) }
    scope :reimbursed, -> { where.not(reimbursement_id: nil) }
    scope :not_reimbursed, -> { where(reimbursement_id: nil) }
    scope :exchange_requested, -> { where.not(exchange_variant: nil) }
    scope :exchange_processed, -> { joins(:exchange_inventory_units).distinct }
    scope :exchange_required, -> { eager_load(:exchange_inventory_units).where(spree_inventory_units: { original_return_item_id: nil }).distinct }
    scope :resellable, -> { where resellable: true }

    serialize :acceptance_status_errors

    delegate :eligible_for_return?, :requires_manual_intervention?, to: :validator
    delegate :variant, to: :inventory_unit
    delegate :shipment, to: :inventory_unit

    before_create :extract_inventory_unit, unless: -> { inventory_unit.quantity == return_quantity }
    before_create :set_default_pre_tax_amount, unless: :pre_tax_amount_changed?

    before_save :set_exchange_pre_tax_amount

    state_machine :reception_status, initial: :awaiting do
      after_transition to: :received, do: :attempt_accept
      after_transition to: :received, do: :process_inventory_unit!

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

    extend DisplayMoney
    money_methods :pre_tax_amount, :total

    def reception_completed?
      COMPLETED_RECEPTION_STATUSES.include?(reception_status)
    end

    state_machine :acceptance_status, initial: :pending do
      event :attempt_accept do
        transition to: :accepted, from: :accepted
        transition to: :accepted, from: :pending, if: ->(return_item) { return_item.eligible_for_return? }
        transition to: :manual_intervention_required, from: :pending, if: ->(return_item) { return_item.requires_manual_intervention? }
        transition to: :rejected, from: :pending
      end

      # bypasses eligibility checks
      event :accept do
        transition to: :accepted, from: [:accepted, :pending, :manual_intervention_required]
      end

      # bypasses eligibility checks
      event :reject do
        transition to: :rejected, from: [:accepted, :pending, :manual_intervention_required]
      end

      # bypasses eligibility checks
      event :require_manual_intervention do
        transition to: :manual_intervention_required, from: [:accepted, :pending, :manual_intervention_required]
      end

      after_transition any => any, do: :persist_acceptance_status_errors
    end

    def self.from_inventory_unit(inventory_unit)
      not_cancelled.find_by(inventory_unit: inventory_unit) ||
        new(inventory_unit: inventory_unit).tap(&:set_default_pre_tax_amount)
    end

    def exchange_requested?
      exchange_variant.present?
    end

    def exchange_processed?
      exchange_inventory_units.present?
    end

    def exchange_required?
      exchange_requested? && !exchange_processed?
    end

    def total
      pre_tax_amount + included_tax_total + additional_tax_total
    end

    def eligible_exchange_variants
      exchange_variant_engine.eligible_variants(variant)
    end

    def build_default_exchange_inventory_unit
      # The inventory unit needs to have the new variant
      # but it also needs to know the original line item
      # for pricing information for if the inventory unit is
      # ever returned. This means that the inventory unit's line_item
      # will have a different variant than the inventory unit itself
      return unless exchange_required?
      exchange_inventory_units.build(variant: exchange_variant, line_item: inventory_unit.line_item,
                                     order: inventory_unit.order, quantity: return_quantity)
    end

    def exchange_shipments
      exchange_inventory_units.map(&:shipment).uniq
    end

    def set_default_pre_tax_amount
      self.pre_tax_amount = refund_amount_calculator.new.compute(self)
    end

    private

    def persist_acceptance_status_errors
      update_attributes(acceptance_status_errors: validator.errors)
    end

    def stock_item
      return unless customer_return

      Spree::StockItem.find_by(variant_id: inventory_unit.variant_id,
                               stock_location_id: customer_return.stock_location_id)
    end

    def currency
      return_authorization.try(:currency) || Spree::Config[:currency]
    end

    def process_inventory_unit!
      inventory_unit.return!
      if should_restock?
        Spree::StockMovement.create!(
          stock_item_id: stock_item.id,
          quantity: inventory_unit.quantity,
          originator: return_authorization
        )
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

    def eligible_exchange_variant
      return unless exchange_variant && exchange_variant_id_changed?
      unless eligible_exchange_variants.include?(exchange_variant)
        errors.add(:base, Spree.t(:invalid_exchange_variant))
      end
    end

    def validator
      @validator ||= return_eligibility_validator.new(self)
    end

    def validate_acceptance_status_for_reimbursement
      if reimbursement && !accepted?
        errors.add(:reimbursement, :cannot_be_associated_unless_accepted)
      end
    end

    def sufficient_quantity_for_return
      # Only perform the check if everything is good so far
      return unless errors.empty? && return_quantity > inventory_unit.quantity
      errors.add(:return_quantity, Spree.t(:cannot_return_more_than_bought_quantity))
    end

    def extract_inventory_unit
      self.inventory_unit = inventory_unit.split_inventory!(return_quantity)
    end

    def set_exchange_pre_tax_amount
      self.pre_tax_amount = 0.0.to_d if exchange_requested?
    end

    def validate_no_other_completed_return_items
      other_return_item = Spree::ReturnItem.where(inventory_unit_id: inventory_unit_id,
                                                  reception_status: COMPLETED_RECEPTION_STATUSES).first

      if other_return_item
        errors.add(:inventory_unit, :other_completed_return_item_exists,           inventory_unit_id: inventory_unit_id,
                                                                                   return_item_id: other_return_item.id)
      end
    end

    def cancel_others
      Spree::ReturnItem.where(inventory_unit_id: inventory_unit_id).where.not(id: id).
        not_cancelled.each(&:cancel!)
    end

    def should_restock?
      resellable? && variant.should_track_inventory? && stock_item && Spree::Config[:restock_inventory]
    end
  end
end
