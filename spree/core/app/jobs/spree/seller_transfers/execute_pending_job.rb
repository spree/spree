module Spree
  module SellerTransfers
    # Asks the provider again about earnings it could not be asked about before.
    #
    # A seller who ships while their payout account is still being verified has
    # earned all the same, so the ledger records the row and leaves it pending.
    # So does a seller whose provider simply refused the call. Either way the
    # money is owed, and no settlement will find it: a sweep collects confirmed
    # earnings, and these are not confirmed.
    #
    # Two callers, for the two ways a row gets here. A seller becoming payable
    # runs it at once, because that is the moment the answer changed. Everyone
    # else is reached by {ExecutePendingDueJob} on a schedule — without it, a
    # seller who was payable all along would never see a refused earning tried
    # again, since nothing about them ever changes to prompt it.
    #
    # Reversals are retried the same way: a provider that pulls money back can
    # refuse too, and one cannot be pulled back before its earning was sent.
    #
    # It takes the retryable rows — never sent, or refused outright. A transfer
    # whose outcome the provider could not report is left alone: asking again
    # is precisely how the same money moves twice, and only a person can say
    # what actually happened.
    class ExecutePendingJob < ::Spree::BaseJob
      queue_as Spree.queues.payouts

      # @param seller_id [Integer]
      def perform(seller_id)
        seller = Spree::Seller.find_by(id: seller_id)
        return if seller.nil?

        Spree::Current.store = seller.store
        send_earnings(seller) if seller.payouts_enabled?

        # Never through `transfer!`: a reversal's amount is negative, and the
        # amount sent is its absolute value, so it would pay the seller the
        # money it exists to take back. Through the provider that made the
        # earning, which is not necessarily the store's current one. And for
        # every seller, payable or not — a seller suspended after a wave of
        # refunds is exactly the one whose money must come back.
        seller.seller_transfers.reversals_awaiting_provider.includes(:reversed_from, :order).find_each do |reversal|
          execute(reversal) { reversal.payout_provider_instance.reverse!(reversal) }
        end
      end

      private

      # Before the reversals, so a reversal waiting on its earning finds it sent.
      def send_earnings(seller)
        provider = seller.store.payout_provider_instance

        seller.seller_transfers.awaiting_provider.find_each do |transfer|
          execute(transfer) { provider.transfer!(transfer) }
        end
      end

      def execute(transfer)
        yield
      rescue Spree::Core::AmbiguousGatewayError => e
        # The money may already have moved, so this row must not be offered
        # again: left retryable, the next run would move it a second time,
        # and an idempotency key stops that only while the provider still
        # holds its record.
        transfer.update!(status: 'unresolved')
        Rails.error.report(e, handled: true, context: { seller_transfer_id: transfer.id }, source: 'spree.core')
      rescue StandardError => e
        # A refusal — the money did not move. One stuck row must not stop the
        # rest, and it stays retryable for the next run.
        Rails.error.report(e, handled: true, context: { seller_transfer_id: transfer.id }, source: 'spree.core')
      end
    end
  end
end
