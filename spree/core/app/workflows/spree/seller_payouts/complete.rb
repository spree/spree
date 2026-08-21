module Spree
  module SellerPayouts
    # Records that a settlement actually reached the seller.
    #
    # Two callers, one meaning. An operator running the built-in provider marks
    # a payout paid once they have sent the bank transfer; a connected provider
    # marks it paid when its webhook says the money landed. Either way this is
    # a claim about the outside world, which is why nothing asserts it
    # automatically at the moment a payout is created.
    #
    # Completing is what debits the seller's balance, since the balance is
    # earnings less *completed* settlements.
    class Complete < Spree::Workflow
      hooks :validate, :after_complete

      # @param seller_payout [Spree::SellerPayout]
      # @param reference [String, nil] the provider's own id for the
      #   settlement, when one made it
      # @return [Spree::ServiceModule::Result]
      def perform(seller_payout:, reference: nil)
        super

        step :replay_completed
        run_hooks :validate
        step :mark_completed
        run_hooks :after_complete

        seller_payout.publish_event('seller_payout.completed')
        success(seller_payout)
      end

      private

      # A webhook can arrive twice, and an operator can double-click. The cheap
      # read catches the ordinary case; the write below catches the race.
      def replay_completed
        halt!(seller_payout) if seller_payout.reload.completed?
      end

      # Compare-and-swap on the terminal write, because an operator marking a
      # bank transfer sent can race the provider's own webhook saying the same
      # thing. Both would pass the read above, both would write `completed`,
      # and the completion event — public API a subscriber may act on — would
      # fire twice for one settlement.
      def mark_completed
        attributes = { status: 'completed', updated_at: Time.current }
        attributes[:reference] = reference if reference.present?

        claimed = Spree::SellerPayout.where(id: seller_payout.id, status: %w[pending processing]).
                  update_all(attributes)

        halt!(seller_payout.reload) if claimed.zero?

        seller_payout.reload
      end
    end
  end
end
