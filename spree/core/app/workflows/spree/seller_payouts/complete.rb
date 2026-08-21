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

      # A webhook can arrive twice, and an operator can double-click.
      def replay_completed
        halt!(seller_payout) if seller_payout.completed?
      end

      def mark_completed
        attributes = { status: 'completed' }
        attributes[:reference] = reference if reference.present?

        seller_payout.update!(attributes)
      end
    end
  end
end
