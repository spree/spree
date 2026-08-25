# frozen_string_literal: true

module Spree
  module SellerRequirements
    # Somewhere to send the seller their money.
    #
    # A checklist row like any other, rather than a card of its own bolted
    # beside the checklist: whether a marketplace asks this before admitting a
    # seller is the operator's decision, exactly as it is for a returns address
    # or a business document. A marketplace paying by hand may not need it at
    # all, which is why the kind is registered but not provisioned by default.
    #
    # What "done" means belongs to the provider, not here. The built-in one
    # never refuses a seller, so this reads as complete the moment it is asked
    # — an operator collecting bank details by email has nothing for the seller
    # to do. A connected provider answers only once it has run its own checks,
    # which can be days after the seller stops typing.
    #
    # The link itself is deliberately not `action_url`. Hosted onboarding links
    # are short-lived and single-use, so one minted while rendering a checklist
    # may be dead before the seller clicks it — the panel asks for a fresh one
    # at the moment of clicking, through the seller API.
    class PayoutAccount < Spree::SellerRequirement
      def met_by_seller?(seller)
        provider_for(seller).onboarded?(seller)
      end

      # Asked of the provider, since only it knows — and its three answers
      # want different words: go and finish, wait, or you have been refused.
      def blocker(seller)
        provider = provider_for(seller)
        state = provider.onboarding_state(seller)
        return nil if state.nil?

        { state: state.to_s, message: provider.onboarding_message(seller) }
      end

      private

      def provider_for(seller)
        (seller.store || store).payout_provider_instance
      end
    end
  end
end
