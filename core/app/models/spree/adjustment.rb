# Adjustments represent a change to the +item_total+ of an Order.  Each adjustment has an +amount+ that be either
# positive or negative.  Adjustments have two useful boolean flags
#
# +mandatory+
#
# If this flag is set to true then it means the the charge is required and will not be removed from the
# order, even if the amount is zero.  In other words a record will be created even if the amount is zero.
# This is  useful for representing things such as shipping and tax charges where you may want to make it explicitly
# clear that no charge was made for such things.
#
# +locked+
#
# The charge is never to be udpated.  Typically you would want to freeze certain adjustments after checkout.
# One use case for this is if you want to lock a shipping adjustment so that its value does not change
# in the future when making other trivial edits to the order (like an email change).
#
# +eligible?+
#
#  This boolean attributes stores whether this adjustment is currently eligible for its order. Only eligible
#  adjustments count towards the order's adjustment total. This allows an adjustment to be preserved if it
#  becomes ineligible so it might be reinstated.
#
module Spree
  class Adjustment < ActiveRecord::Base
    attr_accessible :amount, :label

    belongs_to :adjustable, :polymorphic => true
    belongs_to :source, :polymorphic => true
    belongs_to :originator, :polymorphic => true

    validates :label, :presence => true
    validates :amount, :numericality => true

    after_save :update_adjustable
    after_destroy :update_adjustable

    # Update the boolean _eligible_ attribute which deterimes which adjustments count towards the order's
    # adjustment_total.
    def set_eligibility
      update_attribute_without_callbacks(:eligible,
                                         mandatory ||
                                         (amount != 0 && eligible_for_originator?))
    end

    # Allow originator of the adjustment to perform an additional eligibility of the adjustment
    # Should return _true_ if originator is absent or doesn't implement _eligible?_
    def eligible_for_originator?
      return true if originator.nil?
      !originator.respond_to?(:eligible?) || originator.eligible?(source)
    end

    # Update both the eligibility and amount of the adjustment. Adjustments delegate updating of amount to their Originator
    # when present, but only if +locked+ is false.  Adjustments that are +locked+ will never change their amount.
    # The new adjustment amount will be set by by the +originator+ and is not automatically saved.  This makes it save
    # to use this method in an after_save hook for other models without causing an infinite recursion problem.
    #
    # order#update_adjustments passes self as the src, this is so calculations can be performed on the
    # current values. If we used source it would load the old record from db for the association
    def update!(src = nil)
      src ||= source
      return if locked?
      if originator.present?
        originator.update_adjustment(self, src)
      end
      set_eligibility
    end

    def currency
      Spree::Config[:currency]
    end

    def display_amount
      Spree::Money.new(amount, { :currency => currency }).to_s
    end

    private

      def update_adjustable
        adjustable.update! if adjustable.is_a? Order
      end

      class << self
        def tax
          where(:originator_type => 'Spree::TaxRate', :adjustable_type => 'Spree::Order')
        end

        def price
          where(:adjustable_type => 'Spree::LineItem')
        end

        def shipping
          where(:originator_type => 'Spree::ShippingMethod')
        end

        def optional
          where(:mandatory => false)
        end

        def eligible
          where(:eligible => true)
        end

        def charge
          where('amount >= 0')
        end

        def credit
          where('amount < 0')
        end
      end

  end
end
