# frozen_string_literal: true

module Spree
  # Gives a post-sale workflow one way to put money back on an order.
  #
  # Returns, claims and exchanges all owe the customer money for the same
  # reason — goods that are going back, or were never right — and all three
  # drained `order.payments` to pay it. That reads nothing on a marketplace
  # order: a split checkout takes one charge against the {Spree::OrderGroup},
  # so a child order holds no payments of its own and every one of the three
  # failed with "no refundable payments" on the orders a seller is most likely
  # to be refunding.
  #
  # What a child order holds instead is a {Spree::PaymentSplit} per group
  # payment — its own authorised, captured and refunded share. Refunding
  # through the share is what keeps one seller's refund from spending a
  # sibling's captured money, and it is the same shape
  # {Spree::Orders::Cancel} already settles a canceled child order with.
  module RefundsOrderPayments
    extend ActiveSupport::Concern

    private

    # Puts `amount` back on `order`, newest payment first, until it is covered.
    #
    # A split-tender order needs more than one refund, so this drains rather
    # than picking one payment. Every row goes through
    # {Spree::Refunds::Create}, which owns the row-locked balance check, the
    # gateway credit, the declined-row compensation, the refund hooks and the
    # `payment.refunded` event — so nothing here talks to a gateway itself.
    #
    # @param order [Spree::Order] the order being put right
    # @param amount [BigDecimal] how much to give back
    # @param originator [Spree::Return, Spree::Claim, Spree::Exchange]
    # @param refunder [Object, nil] whoever is issuing it
    # @return [Array<Spree::Refund>] the refunds written, newest payment first
    def refund_order_payments(order:, amount:, originator:, refunder: nil)
      remaining = amount.to_d
      refunds = []

      refundable_shares(order).each do |payment, refundable|
        break unless remaining.positive?

        creditable = [refundable.to_d, remaining].min
        next unless creditable.positive?

        result = Spree.refund_create_workflow.call(
          payment: payment,
          amount: creditable,
          order: order,
          reason: Spree::RefundReason.return_processing_reason(originator.store),
          refunder: refunder,
          originator: originator
        )
        yield(result) if result.failure?

        refunds << result.value
        remaining -= creditable
      end

      refunds
    end

    # What each of the order's completed payments can still give back to *this*
    # order.
    #
    # On an ordinary order that is the payment's own balance. On a child of a
    # split checkout it is that child's share: `credit_allowed` sums the
    # refunds of every child against the whole charge, so measuring one
    # seller's refund by it would let them draw on headroom their sibling's
    # sale is holding.
    #
    # A share mid-capture is skipped rather than guessed at — a parcel reserves
    # what it is about to draw before asking the gateway, so a share can read
    # captured while the charge is still in flight, and refunding through it
    # would hand back money nobody has taken yet. {Spree::Orders::Cancel}
    # leaves the same case for the operator.
    #
    # @param order [Spree::Order]
    # @return [Array<Array(Spree::Payment, BigDecimal)>]
    def refundable_shares(order)
      unless order.grouped?
        return order.payments.completed.map { |payment| [payment, payment.credit_allowed.to_d] }
      end

      order.payment_splits.includes(:payment).filter_map do |split|
        next if split.capture_in_flight?
        next unless split.payment&.completed?

        [split.payment, split.refundable_amount]
      end
    end
  end
end
