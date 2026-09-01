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
    # It takes the retryable rows — never sent, or refused outright. A transfer
    # whose outcome the provider could not report is left alone: asking again
    # is precisely how the same money moves twice, and only a person can say
    # what actually happened.
    class ExecutePendingJob < ::Spree::BaseJob
      queue_as Spree.queues.payouts

      # @param seller_id [Integer]
      def perform(seller_id)
        seller = Spree::Seller.find_by(id: seller_id)
        return if seller.nil? || !seller.payouts_enabled?

        provider = seller.store.payout_provider_instance

        # Earnings only — see the scope. A reversal is retryable the same way
        # when its own provider call is refused, but sending one through
        # `transfer!` would pay the seller the amount it exists to take back:
        # the row is negative and the amount sent is its absolute value.
        seller.seller_transfers.awaiting_provider.find_each do |transfer|
          provider.transfer!(transfer)
        rescue Spree::Core::AmbiguousGatewayError => e
          # The money may already have moved, so this row must not be offered
          # again: left retryable, the next run would send it a second time,
          # and an idempotency key stops that only while the provider still
          # holds its record.
          transfer.update!(status: 'unresolved')
          Rails.error.report(e, handled: true, context: { seller_transfer_id: transfer.id }, source: 'spree.core')
        rescue StandardError => e
          # A refusal — the money did not move. One seller's stuck earning must
          # not stop the rest, and the row stays retryable for the next run.
          Rails.error.report(e, handled: true, context: { seller_transfer_id: transfer.id }, source: 'spree.core')
        end
      end
    end
  end
end
