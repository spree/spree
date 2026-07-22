module Spree
  # A buyer-facing charge on a line item or fulfillment (surcharge, handling,
  # gift wrap, ...) — rolls into order.fee_total and the total the customer
  # pays. Written by custom adjusters registered in Spree.adjusters.
  #
  # Not for platform-vendor settlement: marketplace commission is the
  # off-order CommissionLine ledger, never a Fee.
  class Fee < Spree.base_class
    include Spree::AdjustmentLine

    has_prefix_id :fee

    belongs_to :order, class_name: 'Spree::Order', inverse_of: :fees

    validates :amount, numericality: { greater_than_or_equal_to: 0 }
    validates :kind, presence: true
  end
end
