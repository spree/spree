# frozen_string_literal: true

module Spree
  # Opens onboarding when someone accepts an invitation to run a seller.
  #
  # Acceptance is the moment a seller becomes a business with a person behind
  # it, and it happens on the shared invitation path rather than anywhere
  # marketplace-specific — so the seller's own lifecycle picks it up from the
  # event rather than the invitation flow having to know about sellers.
  class SellerOnboardingSubscriber < Spree::Subscriber
    # Synchronous: the person who just accepted is being sent straight into
    # the seller panel, and it has to find them `onboarding` on arrival — a
    # job that runs a moment later would show them a checklist they cannot
    # yet submit. The transition itself is one row update, so there is no
    # queue worth of work to defer.
    subscribes_to 'invitation.accepted', async: false

    on 'invitation.accepted', :start_seller_onboarding

    private

    def start_seller_onboarding(event)
      invitation = Spree::Invitation.find_by_prefix_id(event.payload['id'])
      return if invitation.nil?

      seller = invitation.resource
      return unless seller.is_a?(Spree::Seller)

      Spree::Sellers::StartOnboarding.call(seller: seller)
    end
  end
end
