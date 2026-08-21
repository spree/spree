module Spree
  module SellerPayouts
    # Settles what a seller has accrued in one currency.
    #
    # The second level of the ledger. It gathers every earning that has been
    # confirmed and not yet settled, batches them into one payout, and asks the
    # provider to send it. A settlement therefore names exactly which orders it
    # covered, which is what a seller needs to reconcile a deposit.
    #
    # **The stamp is the claim.** Creating the payout and marking its transfers
    # with its id happen in one transaction, and a sweep only ever looks at
    # transfers with no payout — so a batch can never be swept twice, and a
    # re-run after a crash finds nothing left to take.
    #
    # A failed send leaves the transfers stamped: the retry re-sends *this*
    # payout rather than sweeping the same earnings into a second one.
    class Sweep < Spree::Workflow
      hooks :validate, :after_sweep

      attr_reader :payout

      # @param seller [Spree::Seller]
      # @param currency [String] settled per currency, since nothing is ever
      #   converted
      # @return [Spree::ServiceModule::Result] value is the payout, or the
      #   seller when there was nothing to settle
      def perform(seller:, currency:)
        super

        step :ensure_payable
        step :collect_transfers
        step :ensure_worth_sending
        run_hooks :validate

        step :claim_transfers
        external_step :execute_payout
        run_hooks :after_sweep

        success(payout)
      end

      private

      # A provider that moves money cannot pay a seller it has no account for.
      # The earnings simply stay unsettled until one exists — they are not
      # lost, and the next sweep will find them.
      def ensure_payable
        return unless provider.class.requires_payout_account?

        halt!(seller) unless seller.payouts_enabled?
      end

      def collect_transfers
        @transfers = seller.seller_transfers.unsettled.where(currency: currency).to_a
        halt!(seller) if @transfers.empty?

        @amount = @transfers.sum(&:amount)
      end

      # Below the threshold the balance carries to the next period rather than
      # being sent — a payout costs the marketplace a fee either way, and a
      # seller would rather have one meaningful deposit than five trivial ones.
      # A balance that has gone negative (reversals outrunning earnings) is
      # likewise left to be absorbed by what comes next.
      def ensure_worth_sending
        halt!(seller) if @amount <= 0
        halt!(seller) if @amount < seller.resolved_minimum_payout_amount
      end

      def claim_transfers
        ApplicationRecord.transaction do
          @payout = Spree::SellerPayout.create!(
            seller: seller,
            amount: @amount,
            currency: currency,
            provider: provider_name,
            status: 'pending',
            period_start: @transfers.map(&:created_at).min,
            period_end: Time.current
          )

          # The claim. A concurrent sweep can only take rows this one has not,
          # so the same earning is never in two payouts.
          claimed = Spree::SellerTransfer.where(id: @transfers.map(&:id), payout_id: nil).
                    update_all(payout_id: @payout.id, updated_at: Time.current)

          # Another sweep beat this one to some of them; the amount would be a
          # lie, so this payout takes only what it actually claimed.
          restate_amount if claimed != @transfers.size
        end
      end

      def restate_amount
        @payout.update!(amount: @payout.transfers.sum(:amount))
      end

      def execute_payout
        provider.pay!(payout)
      rescue StandardError => e
        # The transfers stay stamped deliberately: retrying means re-sending
        # this payout, never sweeping the same earnings into a second one.
        payout.update!(status: 'failed')
        Rails.error.report(e, handled: true, context: { seller_payout_id: payout.id }, source: 'spree.core')
        failure(payout, e.message)
      end

      def provider
        @provider ||= seller.store.payout_provider_instance
      end

      def provider_name
        provider.class.name.demodulize.underscore
      end
    end
  end
end
