module Spree
  module Sellers
    # Opens onboarding: the seller now has someone who can sign in and work
    # through the marketplace's requirements.
    #
    # Run when an invitation to a seller's team is accepted, which is the
    # moment the seller stops being a record the operator created and starts
    # being a business doing something about it.
    class StartOnboarding < Spree::Workflow
      hooks :validate, :after_start_onboarding

      # @param seller [Spree::Seller]
      def perform(seller:)
        super

        step :ensure_startable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_onboarding
        end

        run_hooks :after_start_onboarding
        seller.publish_event('seller.onboarding_started')
        success(seller.reload)
      end

      private

      # A seller already working through their checklist is left alone rather
      # than refused: a second teammate accepting an invitation must not read
      # as an error, and it must not reset anything either.
      def ensure_startable
        halt!(seller) if seller.onboarding?

        return if seller.pending? || seller.invited?

        failure(seller, :not_startable)
      end

      def mark_onboarding
        seller.update!(status: 'onboarding')
      end
    end
  end
end
