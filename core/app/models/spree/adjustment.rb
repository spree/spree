# Adjustments represent a change to the +item_total+ of an Order. Each adjustment
# has an +amount+ that can be either positive or negative.
#
# Adjustments can be open/closed/finalized
#
# Once an adjustment is finalized, it cannot be changed, but an adjustment can
# toggle between open/closed as needed
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
  class Adjustment < ActiveRecord::Base
    belongs_to :adjustable, polymorphic: true
    belongs_to :source, polymorphic: true
    belongs_to :originator, polymorphic: true
    belongs_to :order, :class_name => 'Spree::Order'

    validates :label, presence: true
    validates :amount, numericality: true

    after_save :update_adjustable
    after_destroy :update_adjustable

    state_machine :state, initial: :open do
      event :close do
        transition from: :open, to: :closed
      end

      event :open do
        transition from: :closed, to: :open
      end

      event :finalize do
        transition from: [:open, :closed], to: :finalized
      end
    end

    scope :tax, -> { where(originator_type: 'Spree::TaxRate') }
    scope :price, -> { where(adjustable_type: 'Spree::LineItem') }
    scope :shipping, -> { where(originator_type: 'Spree::ShippingMethod') }
    scope :optional, -> { where(mandatory: false) }
    scope :eligible, -> { where(eligible: true) }
    scope :charge, -> { where('amount >= 0') }
    scope :credit, -> { where('amount < 0') }
    scope :promotion, -> { where(originator_type: 'Spree::PromotionAction') }
    scope :manual, -> { where(originator_type: nil) }
    scope :return_authorization, -> { where(source_type: "Spree::ReturnAuthorization") }
    scope :included, -> { where(included: true)  }
    scope :additional, -> { where(included: false) }

    def promotion?
      originator_type == 'Spree::PromotionAction'
    end

    # Update the boolean _eligible_ attribute which determines which adjustments
    # count towards the order's adjustment_total.
    def set_eligibility
      result = mandatory || ((amount != 0 || promotion?) && eligible_for_originator?)
      update_column(:eligible, result)
    end

    # Allow originator of the adjustment to perform an additional eligibility of the adjustment
    # Should return _true_ if originator is absent or doesn't implement _eligible?_
    def eligible_for_originator?
      return true if originator.nil?
      !originator.respond_to?(:eligible?) || originator.eligible?(source)
    end

    # Update both the eligibility and amount of the adjustment. Adjustments
    # delegate updating of amount to their Originator when present, but only if
    # +locked+ is false. Adjustments that are +locked+ will never change their amount.
    #
    # Adjustments delegate updating of amount to their Originator when present,
    # but only if when they're in "open" state, closed or finalized adjustments
    # are not recalculated.
    #
    # It receives +calculable+ as the updated source here so calculations can be
    # performed on the current values of that source. If we used +source+ it
    # could load the old record from db for the association. e.g. when updating
    # more than on line items at once via accepted_nested_attributes the order
    # object on the association would be in a old state and therefore the
    # adjustment calculations would not performed on proper values
    def update!(calculable = nil)
      return if immutable?
      # Fix for #3381
      # If we attempt to call 'source' before the reload, then source is currently
      # the order object. After calling a reload, the source is the Shipment.
      reload
      calculable = source unless calculable == source
      originator.update_adjustment(self, calculable) if originator.present?
      set_eligibility
    end

    def currency
      adjustable ? adjustable.currency : Spree::Config[:currency]
    end

    def display_amount
      Spree::Money.new(amount, { currency: currency })
    end

    def immutable?
      state != "open"
    end

    private

      def update_adjustable
        adjustable.update! if adjustable.is_a? Order
      end
  end
end
