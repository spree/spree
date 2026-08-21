module Spree
  module SellerTransfers
    # Asks the provider again about earnings it could not be asked about before.
    #
    # A seller who ships while their payout account is still being verified has
    # earned all the same, so the ledger records the row and leaves it pending.
    # What clears it is this job, run when the seller becomes payable — the
    # event that changed, rather than the next scheduled settlement.
    #
    # That distinction matters: a sweep would never reach these rows, because
    # it looks for confirmed earnings and a seller whose only rows are pending
    # has none, so nothing would prompt it in the one case this exists for.
    class ExecutePendingJob < ::Spree::BaseJob
      queue_as Spree.queues.payouts

      # @param seller_id [Integer]
      def perform(seller_id)
        seller = Spree::Seller.find_by(id: seller_id)
        return if seller.nil? || !seller.payouts_enabled?

        provider = seller.store.payout_provider_instance

        seller.seller_transfers.pending.where(payout_id: nil).find_each do |transfer|
          provider.transfer!(transfer)
        rescue StandardError => e
          # One seller's stuck earning must not stop the rest — the row stays
          # pending and the next attempt finds it.
          Rails.error.report(e, handled: true, context: { seller_transfer_id: transfer.id }, source: 'spree.core')
        end
      end
    end
  end
end
