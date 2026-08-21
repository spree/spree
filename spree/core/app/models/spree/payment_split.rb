# frozen_string_literal: true

module Spree
  # One child order's share of one payment made against an order group.
  #
  # A grouped checkout takes a single charge — the customer authorised one
  # amount, and creating N gateway charges would change what they agreed to.
  # The per-seller bookkeeping is these rows: each child order's authorised,
  # captured and refunded share of that one payment.
  #
  # Durable rather than computed on read, because the shares stop being
  # proportional the moment anything partial happens: one seller ships and is
  # captured while another has not, one child is refunded and its siblings are
  # not. A proportion recomputed from current totals cannot express that
  # history; a row can.
  #
  # Every payment on the group gets its own set of rows — the gateway charge,
  # the store credit, the gift card — so a child's shares across all of them
  # sum to that child's total, whatever the customer paid with.
  class PaymentSplit < Spree.base_class
    has_prefix_id :paysp

    #
    # Associations
    #
    belongs_to :payment, class_name: 'Spree::Payment', inverse_of: :payment_splits
    belongs_to :order, class_name: 'Spree::Order', inverse_of: :payment_splits

    #
    # Validations
    #
    validates :authorized_amount, :captured_amount, :refunded_amount, numericality: true
    validates :currency, presence: true
    validates :order_id, uniqueness: { scope: [:payment_id, *spree_base_uniqueness_scope] }

    #
    # Scopes
    #
    self.whitelisted_ransackable_attributes = %w[currency authorized_amount captured_amount refunded_amount]
    self.whitelisted_ransackable_associations = %w[payment order]

    extend Spree::DisplayMoney
    money_methods :authorized_amount, :captured_amount, :refunded_amount

    # @return [BigDecimal] what this child still has captured against it after
    #   refunds — the figure a seller's earnings are computed from
    def net_captured_amount
      captured_amount - refunded_amount
    end
  end
end
