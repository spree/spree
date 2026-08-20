require 'spec_helper'

RSpec.describe 'seller onboarding lifecycle' do
  let(:store) { @default_store }

  describe Spree::Sellers::StartOnboarding do
    it 'opens onboarding for an invited seller' do
      seller = create(:seller, store: store, status: 'invited')

      expect(described_class.call(seller: seller)).to be_success
      expect(seller.reload).to be_onboarding
    end

    it 'leaves a seller already onboarding alone rather than erroring' do
      seller = create(:seller, :onboarding, store: store)

      expect(described_class.call(seller: seller)).to be_success
      expect(seller.reload).to be_onboarding
    end

    it 'refuses a seller who is already trading' do
      seller = create(:seller, :approved, store: store)

      expect(described_class.call(seller: seller)).to be_failure
    end
  end

  describe Spree::Sellers::ReopenOnboarding do
    it 'sends a seller awaiting review back with a note' do
      seller = create(:seller, store: store, status: 'ready_for_review')

      result = described_class.call(seller: seller, note: 'Returns address is a PO box')

      expect(result).to be_success
      expect(seller.reload).to be_onboarding
      expect(seller.metadata['onboarding_reopened_note']).to eq('Returns address is a PO box')
    end

    it 'refuses a seller who is not awaiting review' do
      seller = create(:seller, :approved, store: store)

      expect(described_class.call(seller: seller)).to be_failure
    end
  end

  describe 'accepting an invitation to a seller' do
    it 'opens onboarding' do
      seller = create(:seller, store: store, status: 'invited')
      invitation = create(:invitation, resource: seller, role: seller.default_user_role)

      Spree::SellerOnboardingSubscriber.new.send(
        :start_seller_onboarding,
        instance_double(Spree::Event, payload: { 'id' => invitation.prefixed_id })
      )

      expect(seller.reload).to be_onboarding
    end

    # Through the real event bus, with the subscribers the engine registers:
    # calling the handler directly proves the handler, not that anything ever
    # calls it. This is the difference between the flow working in a spec and
    # working in a running marketplace.
    it 'opens onboarding through the event the acceptance publishes', events: true do
      seller = create(:seller, store: store, status: 'invited')
      invitee = create(:admin_user, :without_admin_role)
      invitation = create(:invitation, resource: seller, email: invitee.email,
                                       role: seller.default_user_role)

      invitation.update!(invitee: invitee)
      invitation.accept!

      expect(seller.reload).to be_onboarding
    end
  end
end
