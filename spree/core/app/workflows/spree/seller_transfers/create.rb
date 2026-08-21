module Spree
  module SellerTransfers
    # Credits a seller for one order whose goods have gone out.
    #
    # The first level of the ledger. What the seller earned is their sale less
    # what the marketplace charged them, and it is **payment-source-agnostic**:
    # store credit and gift cards are how the customer paid, which is the
    # platform's funding concern. The seller is owed their cut either way.
    #
    # Idempotent by the unique index on `(order_id) WHERE kind = 'earning'` —
    # the fulfillment event can fire more than once (it is dual-emitted under a
    # legacy name for one release), and a re-fired event must find the earning
    # that exists rather than credit the seller twice.
    class Create < Spree::Workflow
      hooks :validate, :after_create

      attr_reader :seller_transfer

      # @param order [Spree::Order] the seller's order, fully fulfilled
      # @return [Spree::ServiceModule::Result] value is the Spree::SellerTransfer,
      #   or the order when there is nothing to credit
      def perform(order:)
        super

        step :ensure_creditable
        step :replay_existing
        run_hooks :validate

        step :build_transfer
        external_step :execute_transfer
        run_hooks :after_create

        success(seller_transfer)
      end

      private

      # A first-party order earns nobody anything — the money is already the
      # operator's. Nor does an order whose goods have not all gone out, or one
      # with no goods at all: `fully_fulfilled?` answers true for an order with
      # no fulfillments, since none of nothing is outstanding.
      def ensure_creditable
        halt!(order) if order.seller_id.blank?
        halt!(order) if order.fulfillments.empty?
        halt!(order) unless order.fully_fulfilled?
      end

      def replay_existing
        existing = Spree::SellerTransfer.earnings.find_by(order_id: order.id)
        halt!(existing) if existing
      end

      def build_transfer
        @seller_transfer = Spree::SellerTransfer.create!(
          store: order.seller.store,
          seller: order.seller,
          order: order,
          amount: earned_amount,
          currency: order.currency,
          kind: 'earning',
          provider: provider_name,
          status: 'pending'
        )
      rescue ActiveRecord::RecordNotUnique
        # Another delivery of the same event got there first; the unique index
        # is what makes that safe, and its winner is the answer.
        halt!(Spree::SellerTransfer.earnings.find_by!(order_id: order.id))
      end

      # Outside any transaction: a provider that moves money makes a network
      # call here, and a row lock must not be held across it.
      def execute_transfer
        # A seller the provider cannot pay yet keeps the earning as a pending
        # row. Verification can take days, and an account can lose the
        # capability again — either way the money is owed, and
        # `SellerTransfers::ExecutePendingJob` sends it once they are payable.
        return unless order.seller.payouts_enabled?

        provider.transfer!(seller_transfer)
      rescue StandardError => e
        # The money may or may not have moved — that is precisely what an
        # operator has to resolve, so the row parks rather than pretending.
        seller_transfer.update!(status: 'processing')
        Rails.error.report(e, handled: true, context: { seller_transfer_id: seller_transfer.id },
                              source: 'spree.core')
        failure(seller_transfer, e.message)
      end

      # What the seller earned: their sale, less the marketplace's commission
      # including the VAT charged on it — the platform invoices the seller for
      # both, and the seller reclaims that VAT as input tax.
      #
      # A platform-remitted seller does not receive the consumer tax either,
      # since the marketplace files it (Decision 9).
      def earned_amount
        base = order.total.to_d
        base -= order.additional_tax_total.to_d if order.seller.tax_remittance == 'platform'

        [base - order.commission_lines.sum(:total).to_d, 0].max
      end

      def provider
        @provider ||= order.store.payout_provider_instance
      end

      def provider_name
        provider.class.provider_key
      end
    end
  end
end
