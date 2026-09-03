# frozen_string_literal: true

module Spree
  module Refunds
    # Gives a post-sale workflow one way to put money back on an order.
    #
    # Returns, claims and exchanges all owe the customer money for the same
    # reason — goods that are going back, or were never right — and all three
    # drained `order.payments` to pay it. That reads nothing on a marketplace
    # order: a split checkout takes one charge against the
    # {Spree::OrderGroup}, so a child order holds no payments of its own and
    # every one of the three failed with "no refundable payments" on the
    # orders a seller is most likely to be refunding.
    #
    # What a child order holds instead is a {Spree::PaymentSplit} per group
    # payment — its own authorised, captured and refunded share. Refunding
    # through the share is what keeps one seller's refund from spending a
    # sibling's captured money, and it is the same shape
    # {Spree::Orders::Cancel} already settles a canceled child order with.
    module OrderPayments
      extend ActiveSupport::Concern

      private

      # Puts `amount` back on `order`, oldest payment first, until it is
      # covered.
      #
      # A split-tender order needs more than one refund, so this drains rather
      # than picking one payment; oldest first, which is the order the customer
      # paid in and the order both branches below read in.
      #
      # Every row goes through {Spree::Refunds::Create}, which owns the
      # row-locked balance check, the gateway credit, the declined-row
      # compensation, the refund hooks and the `payment.refunded` event — so
      # nothing here talks to a gateway itself.
      #
      # @param order [Spree::Order] the order being put right
      # @param amount [BigDecimal] how much to give back
      # @param record [Spree::Return, Spree::Claim, Spree::Exchange] what asked
      #   for the refund; it originates the rows and carries any failure
      # @param refunder [Object, nil] whoever is issuing it
      # @return [Array<Spree::Refund>] the refunds written, in drain order
      def refund_order_payments(order:, amount:, record:, refunder: nil)
        remaining = amount.to_d
        refunds = []
        shares = refundable_shares(order)
        # Resolved once rather than per payment — but only once there is
        # something to refund, since it is a find_or_create_by and a run that
        # refunds nothing should leave no reason row behind.
        reason = Spree::RefundReason.return_processing_reason(record.store) if shares.any?

        shares.each do |payment, refundable|
          break unless remaining.positive?

          creditable = [refundable, remaining].min
          next unless creditable.positive?

          result = Spree.refund_create_workflow.call(
            payment: payment,
            amount: creditable,
            order: order,
            reason: reason,
            refunder: refunder,
            originator: record
          )
          # `failure` raises, so this ends the drain — the caller's own error
          # vocabulary decorates the 422.
          failure(record, result.error.value) if result.failure?

          refunds << result.value
          remaining -= creditable
        end

        refunds
      end

      # What each of the order's completed payments can still give back to
      # *this* order.
      #
      # On an ordinary order that is the payment's own balance. On a child of
      # a split checkout it is that child's share: `credit_allowed` sums the
      # refunds of every child against the whole charge, so measuring one
      # seller's refund by it would let them draw on headroom their sibling's
      # sale is holding.
      #
      # @param order [Spree::Order]
      # @return [Hash{Spree::Payment => BigDecimal}]
      def refundable_shares(order)
        unless order.grouped?
          return order.payments.completed.order(:created_at).
                 to_h { |payment| [payment, payment.credit_allowed.to_d] }
        end

        # One query for the whole run rather than one per share — this runs
        # ahead of a gateway round trip per payment, and there is no reason to
        # add N more of its own.
        refunded = Spree::Refund.where(order_id: order.id).group(:payment_id).sum(:amount)

        order.payment_splits.includes(:payment).order(:created_at).each_with_object({}) do |split, found|
          next unless split.payment&.completed?
          next if capture_in_flight?(order, split)

          found[split.payment] = split.captured_amount - refunded.fetch(split.payment_id, 0)
        end
      end

      # Whether a charge against this share is still in flight.
      #
      # A parcel reserves what it is about to draw before asking the gateway,
      # so a share can read captured while the charge is still landing.
      # Refunding through it would hand back money nobody has taken yet, so it
      # is reported for the operator rather than guessed at — the same call
      # {Spree::Orders::Cancel} makes when it meets one.
      #
      # @return [Boolean]
      def capture_in_flight?(order, split)
        return false unless split.capture_in_flight?

        Rails.error.report(
          Spree::Core::GatewayError.new('Payment share is mid-capture; refund left it for manual settlement'),
          handled: true,
          context: { order_id: order.id, payment_split_id: split.id },
          source: 'spree.core'
        )
        true
      end
    end
  end
end
