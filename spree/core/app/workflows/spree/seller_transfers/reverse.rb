module Spree
  module SellerTransfers
    # Takes back part of what a seller earned, after a refund.
    #
    # Written as its own negative row rather than by editing the earning, so
    # what a seller has earned is always the sum of their transfers and the
    # history stays readable. If the earning was already settled in a closed
    # payout, the reversal simply lands in the next period — a settlement that
    # happened is never rewritten.
    #
    # The ledger row is written in every tier. Whether money is actually pulled
    # back is the provider's business, and the built-in one pulls back nothing.
    class Reverse < Spree::Workflow
      hooks :validate, :after_reverse

      attr_reader :reversal

      # @param order [Spree::Order] the seller order being refunded
      # @param amount [BigDecimal, Numeric] how much of the earning to take
      #   back; capped at what is left of it
      # @return [Spree::ServiceModule::Result] value is the reversal, or the
      #   order when there was nothing to reverse
      def perform(order:, amount:)
        super

        step :find_earning
        step :bound_amount
        run_hooks :validate

        step :build_reversal
        external_step :execute_reversal
        run_hooks :after_reverse

        success(reversal)
      end

      private

      def find_earning
        @earning = Spree::SellerTransfer.earnings.find_by(order_id: order.id)
        # Nothing was ever credited — the order was refunded before it shipped,
        # which is the ordinary case and not an error.
        halt!(order) if @earning.nil?
      end

      # Never more than is left of the earning, however many times an order is
      # refunded: a marketplace cannot claw back more than it credited.
      def bound_amount
        @bounded = [amount.to_d.abs, @earning.reversible_amount].min
        halt!(order) if @bounded <= 0
      end

      def build_reversal
        @reversal = Spree::SellerTransfer.create!(
          seller: @earning.seller,
          order: order,
          reversed_from: @earning,
          # Negative, so what a seller has earned is the plain sum of the rows.
          amount: -@bounded,
          currency: @earning.currency,
          kind: 'refund_reversal',
          provider: @earning.provider,
          status: 'pending'
        )
      end

      def execute_reversal
        provider.reverse!(reversal)
      rescue StandardError => e
        reversal.update!(status: 'processing')
        Rails.error.report(e, handled: true, context: { seller_transfer_id: reversal.id }, source: 'spree.core')
        failure(reversal, e.message)
      end

      def provider
        @provider ||= order.store.payout_provider_instance
      end
    end
  end
end
