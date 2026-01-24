# Adjustments represent a change to the +item_total+ of an Order. Each adjustment
# has an +amount+ that can be either positive or negative.
#
# Adjustments can be "opened" or "closed".
# Once an adjustment is closed, it will not be automatically updated.
#
# Boolean attributes:
#
# +mandatory+
#
# If this flag is set to true then it means the the charge is required and will not
# be removed from the order, even if the amount is zero. In other words a record
# will be created even if the amount is zero. This is useful for representing things
# such as shipping and tax charges where you may want to make it explicitly clear
# that no charge was made for such things.
#
# +eligible?+
#
# This boolean attributes stores whether this adjustment is currently eligible
# for its order. Only eligible adjustments count towards the order's adjustment
# total. This allows an adjustment to be preserved if it becomes ineligible so
# it might be reinstated.
module Spree
  class Adjustment < Spree.base_class
    has_prefix_id :adj  # Spree-specific: adjustment

    with_options polymorphic: true do
      belongs_to :adjustable, touch: true
      belongs_to :source
    end
    belongs_to :order, class_name: 'Spree::Order', inverse_of: :all_adjustments
    belongs_to :promotion_action, class_name: 'Spree::PromotionAction', foreign_key: :source_id, optional: true # created only for has_free_shipping?

    validates :adjustable, :order, :label, presence: true
    validates :amount, numericality: true

    state_machine :state, initial: :open do
      event :close do
        transition from: :open, to: :closed
      end

      event :open do
        transition from: :closed, to: :open
      end
    end

    # FIXME: we should check if we also need to fire this action after update
    after_create :update_adjustable_adjustment_total
    after_destroy :update_adjustable_adjustment_total

    class_attribute :competing_promos_source_types

    self.competing_promos_source_types = ['Spree::PromotionAction']

    scope :not_finalized, -> { where(state: 'open') }
    scope :finalized, -> { where(state: 'closed') }
    scope :tax, -> { where(source_type: 'Spree::TaxRate') }
    scope :non_tax, -> do
      source_type = arel_table[:source_type]
      where(source_type.not_eq('Spree::TaxRate').or(source_type.eq(nil)))
    end
    scope :price, -> { where(adjustable_type: 'Spree::LineItem') }
    scope :shipping, -> { where(adjustable_type: 'Spree::Shipment') }
    scope :optional, -> { where(mandatory: false) }
    scope :eligible, -> { where(eligible: true) }
    scope :charge, -> { where("#{quoted_table_name}.amount >= 0") }
    scope :credit, -> { where("#{quoted_table_name}.amount < 0") }
    scope :nonzero, -> { where("#{quoted_table_name}.amount != 0") }
    scope :non_zero, -> { where.not(amount: [nil, 0]) }
    scope :promotion, -> { where(source_type: 'Spree::PromotionAction') }
    scope :return_authorization, -> { where(source_type: 'Spree::ReturnAuthorization') }
    scope :is_included, -> { where(included: true) }
    scope :additional, -> { where(included: false) }
    scope :competing_promos, -> { where(source_type: competing_promos_source_types) }
    scope :for_complete_order, -> { joins(:order).merge(Spree::Order.complete) }
    scope :for_incomplete_order, -> { joins(:order).merge(Spree::Order.incomplete) }

    extend DisplayMoney
    money_methods :amount

    def amount=(amount)
      self[:amount] = Spree::LocalizedNumber.parse(amount)
    end

    def currency
      adjustable ? adjustable.currency : order.currency
    end

    def promotion?
      source_type == 'Spree::PromotionAction'
    end

    def tax?
      source_type == 'Spree::TaxRate'
    end

    def additional?
      !included?
    end

    # Returns the source using Rails.cache to avoid repeated database lookups.
    # Sources are cached by their type and ID combination.
    # Cache is automatically invalidated when the source is saved (see AdjustmentSource concern).
    #
    # @return [Object, nil] The source object (TaxRate, PromotionAction, etc.)
    def cached_source
      return nil if source_type.blank? || source_id.blank?

      Rails.cache.fetch(source_cache_key) { source }
    rescue TypeError
      # Handle objects that can't be serialized (e.g., mock objects in tests)
      source
    end

    # Cache key for the source object
    def source_cache_key
      "spree/adjustment_source/#{source_type}/#{source_id}"
    end

    # Passing a target here would always be recommended as it would avoid
    # hitting the database again and would ensure you're compute values over
    # the specific object amount passed here.
    def update!(target = adjustable)
      src = cached_source
      return amount if closed? || src.blank?

      new_amount = src.compute_amount(target)
      new_eligible = promotion? ? src.promotion.eligible?(target) : eligible

      changed_attributes = {}
      changed_attributes[:amount] = new_amount if new_amount != amount
      changed_attributes[:eligible] = new_eligible if new_eligible != eligible

      if changed_attributes.any?
        changed_attributes[:updated_at] = Time.current
        update_columns(changed_attributes)
      end

      new_amount
    end

    private

    def update_adjustable_adjustment_total
      # Cause adjustable's total to be recalculated
      Adjustable::AdjustmentsUpdater.update(adjustable)
    end
  end
end
