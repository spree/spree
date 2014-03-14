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
  class Adjustment < ActiveRecord::Base
    belongs_to :adjustable, polymorphic: true
    belongs_to :source, polymorphic: true
    belongs_to :order, :class_name => "Spree::Order"

    validates :label, presence: true
    validates :amount, numericality: true

    state_machine :state, initial: :open do
      event :close do
        transition from: :open, to: :closed
      end

      event :open do
        transition from: :closed, to: :open
      end
    end

    after_create :update_adjustable_adjustment_total

    scope :open, -> { where(state: 'open') }
    scope :closed, -> { where(state: 'closed') }
    scope :tax, -> { where(source_type: 'Spree::TaxRate') }
    scope :price, -> { where(adjustable_type: 'Spree::LineItem') }
    scope :shipping, -> { where(adjustable_type: 'Spree::Shipment') }
    scope :optional, -> { where(mandatory: false) }
    scope :eligible, -> { where(eligible: true) }
    scope :charge, -> { where("#{quoted_table_name}.amount >= 0") }
    scope :credit, -> { where("#{quoted_table_name}.amount < 0") }
    scope :promotion, -> { where(source_type: 'Spree::PromotionAction') }
    scope :return_authorization, -> { where(source_type: "Spree::ReturnAuthorization") }
    scope :included, -> { where(included: true)  }
    scope :additional, -> { where(included: false) }

    def closed?
      state == "closed"
    end

    def promotion?
      source.class < Spree::PromotionAction
    end

    # Recalculate amount given a target e.g. Order, Shipment, LineItem
    #
    # Passing a target here would always be recommended as it would avoid
    # hitting the database again and would ensure you're compute values over
    # the specific object amount passed here.
    #
    # Noop if the adjustment is locked.
    #
    # If the adjustment has no source, do not attempt to re-calculate the amount.
    # Chances are likely that this was a manually created adjustment in the admin backend.
    def update!(target = nil)
      return amount if closed?
      if source.present?
        amount = source.compute_amount(target || adjustable)
        self.update_columns(
          amount: amount,
          updated_at: Time.now,
        )
        if promotion?
          self.update_column(:eligible, source.promotion.eligible?(adjustable))
        end
      end
      amount
    end

    def currency
      adjustable ? adjustable.currency : Spree::Config[:currency]
    end

    def display_amount
      Spree::Money.new(amount, { currency: currency })
    end

    private

    def update_adjustable_adjustment_total
      # Cause adjustable's total to be recalculated
      Spree::ItemAdjustments.new(adjustable).update if adjustable
    end
  end
end
