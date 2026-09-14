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
      # that came back, so what comes back is always the seller's share of it.
      #
      # Which share depends on what the refund can say about itself. A return or
      # a claim names the lines it paid for, and those lines earned a knowable
      # amount. Anything else — a manual refund, a cancellation — is only an
      # amount against an order, and the order's own ratio is the best available
      # answer.
      def seller_share_of(refunded)
        attributed_share(refunded) || blended_share(refunded)
      end

      # What the named lines actually earned, scaled to what this refund paid.
      #
      # The scaling is not a refinement: one return is refunded once per payment
      # it draws on, and every one of those refunds names the same lines. Taking
      # them at face value would claw the same units back once per payment.
      # Scaling also absorbs an operator who refunded a different amount than the
      # lines are worth — a restocking fee, or goodwill on top.
      #
      # Nil when the refund names nothing, which sends the caller to the blend.
      def attributed_share(refunded)
        amounts = refund&.refunded_line_amounts
        return if amounts.blank?

        gross = amounts.values.sum.to_d
        return if gross <= 0

        # Nil from any line means the attribution cannot be trusted whole, so
        # the blend answers for the refund rather than part of it.
        earnings = amounts.map { |line_item_id, amount| line_earning(line_item_id, amount.to_d) }
        return if earnings.any?(&:nil?)

        quantize(earnings.sum * (refunded.to_d.abs / gross))
      end

      def blended_share(refunded)
        paid = order.total.to_d
        return refunded.to_d.abs if paid.zero?

        quantize(refunded.to_d.abs * (@earning.amount / paid))
      end

      # What one line's refunded value earned the seller: their money less the
      # commission charged on it, and less the consumer tax when the marketplace
      # remits it — mirroring how the earning itself was worked out.
      #
      # The commission comes from the row written against that line at
      # placement, not from today's rate: rates change, a clamped fee is not the
      # rate times the base, and a fixed rate is charged per unit.
      def line_earning(line_item_id, amount)
        line_item = order_line_items[line_item_id]
        paid = line_item&.amount.to_d
        # A line this order does not carry, or one worth nothing, says nothing
        # about what the seller earned. Answering the gross would claw back the
        # commission and the tax they never received, which is the whole thing
        # this is here to avoid, so the caller falls back to the order's ratio.
        return if paid.zero?

        # Only ever a fraction of the line, so a clamped commission is divided
        # rather than reasoned about — the best available attribution.
        share = amount / paid
        earned = amount - (commission_totals[line_item_id].to_d * share)
        earned -= line_item.tax_total.to_d * share if order.seller&.tax_remittance == 'platform'
        earned
      end

      def order_line_items
        @order_line_items ||= order.line_items.index_by(&:id)
      end

      def commission_totals
        @commission_totals ||= Spree::CommissionLine.for_line_items.
                               where(line_item_id: order_line_items.keys).
                               pluck(:line_item_id, :total).to_h
      end

      def quantize(amount)
        Spree::Money::Rounding.quantize(amount, Spree::Money::Rounding.precision(@earning.currency))
      end

      # Nil when there is nothing left to take back, which the caller turns
      # into a halt outside the transaction — `halt!` refuses to run inside one.
      def write_reversal
        @earning.with_lock do
          bounded = [seller_share_of(amount), @earning.reversible_amount].min
          next nil if bounded <= 0

          Spree::SellerTransfer.create!(
            {
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
            }.merge(settlement_of(bounded))
          )
        end
      end

      # A clawback has to settle where its earning settled. Payouts are swept by
      # settlement currency, so a reversal left in the sale's currency would
      # never join the batch that pays the earning it cancels — the seller would
      # be paid in full for goods that came back, and the row would sit in a
      # currency their account cannot pay.
      #
      # Prorated from the earning's own settled figure rather than converted at
      # today's rate, so the money comes back at the rate it went out at.
      def settlement_of(bounded)
        return {} if @earning.settled_amount.blank? || @earning.amount.zero?

        share = @earning.settled_amount * (bounded / @earning.amount)

        {
          settled_amount: -Spree::Money::Rounding.quantize(
            share, Spree::Money::Rounding.precision(@earning.settlement_currency)
          ),
          settled_currency: @earning.settled_currency
        }
      end

      def execute_reversal
        provider.reverse!(reversal)
      rescue Spree::Core::AmbiguousGatewayError => e
        # Whether the clawback happened is the provider's to say. Recorded as
        # such rather than as a refusal, so an operator reconciling knows which
        # rows are questions and which are simply owed.
        reversal.update!(status: 'unresolved')
        Rails.error.report(e, handled: true, context: { seller_transfer_id: reversal.id }, source: 'spree.core')
        failure(reversal, e.message)
      rescue StandardError => e
        reversal.update!(status: 'processing')
        Rails.error.report(e, handled: true, context: { seller_transfer_id: reversal.id }, source: 'spree.core')
        failure(reversal, e.message)
      end

      # The provider that made the earning, not whichever one the store uses
      # now. A marketplace that changes provider still has money sitting with
      # the old one, and asking the new one to reverse a transfer it never
      # made leaves the original standing — the seller keeps a refunded sale.
      def provider
        @provider ||= begin
          configured = Spree.payout_providers.find { |candidate| candidate.to_s == @earning.provider }

          # No silent fallback to whatever the store uses now. A provider that
          # is no longer installed still holds the transfer this reverses, and
          # handing the job to a different one would mark the row reversed
          # while the money stayed where it was. An operator has to know.
          if configured.nil?
            raise Spree::Core::GatewayError,
                  "Payout provider #{@earning.provider} is not registered, so its transfer cannot be reversed"
          end

          configured.new
        end
      end
    end
  end
end
