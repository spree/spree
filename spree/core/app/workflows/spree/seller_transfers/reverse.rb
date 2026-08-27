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
      # @param refund [Spree::Refund, nil] what caused the clawback. The
      #   reversal's natural key, so a redelivered event reverses once.
      # @return [Spree::ServiceModule::Result] value is the reversal, or the
      #   order when there was nothing to reverse
      def perform(order:, amount:, refund: nil)
        super

        step :find_earning
        step :replay_existing
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

      # An event can be delivered twice, and a job can retry.
      def replay_existing
        return if refund.nil?

        existing = Spree::SellerTransfer.reversals_only.find_by(refund_id: refund.id)
        halt!(existing) if existing.present?
      end

      # Bounded and written under the earning's own lock, so two refunds
      # landing together cannot each read the same untouched earning and each
      # take the whole of it. The unique index on `refund_id` covers the other
      # race — the same refund arriving twice — and resolves to the row that
      # won rather than failing the caller.
      def build_reversal
        @reversal = write_reversal
        halt!(order) if @reversal.nil?
      rescue ActiveRecord::RecordNotUnique
        # Only a refund-keyed reversal can collide, since that index is what
        # makes it unique. Re-raising anything else keeps the real error
        # visible rather than replacing it with a lookup that cannot succeed.
        raise if refund.nil?

        halt!(Spree::SellerTransfer.reversals_only.find_by!(refund_id: refund.id))
      end

      # The seller's share of a refunded amount.
      #
      # A refund is the customer's gross figure — it carries the tax and the
      # marketplace's commission, while the seller only ever received their net
      # cut. Taking the gross back would charge them the commission on goods
      # that came back, so it is scaled by what the order earned them against
      # what the customer paid. A full refund still nets to the whole earning.
      def seller_share_of(refunded)
        paid = order.total.to_d
        return refunded.to_d.abs if paid.zero?

        Spree::Money::Rounding.quantize(
          refunded.to_d.abs * (@earning.amount / paid),
          Spree::Money::Rounding.precision(@earning.currency)
        )
      end

      # Nil when there is nothing left to take back, which the caller turns
      # into a halt outside the transaction — `halt!` refuses to run inside one.
      def write_reversal
        @earning.with_lock do
          bounded = [seller_share_of(amount), @earning.reversible_amount].min
          next nil if bounded <= 0

          Spree::SellerTransfer.create!(
            store: @earning.store,
            seller: @earning.seller,
            order: order,
            reversed_from: @earning,
            refund: refund,
            # Negative, so what a seller has earned is the plain sum of the rows.
            amount: -bounded,
            currency: @earning.currency,
            kind: 'refund_reversal',
            provider: @earning.provider,
            status: 'pending'
          )
        end
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
