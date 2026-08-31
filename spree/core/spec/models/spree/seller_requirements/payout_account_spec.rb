require 'spec_helper'

RSpec.describe Spree::SellerRequirements::PayoutAccount do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }
  let(:requirement) { described_class.create!(store: store, name: 'Payout account', required: true) }

  describe '#met_by_seller?' do
    # An operator paying by bank transfer collects these details themselves,
    # so there is nothing for the seller to do and nothing to wait for.
    context 'with the record-only provider' do
      it 'is met, since the provider never refuses a seller' do
        expect(requirement).to be_met_by_seller(seller)
      end
    end

    context 'with a provider that pays sellers itself' do
      before do
        allow(Spree::PayoutProvider::System).to receive(:requires_payout_account?).and_return(true)
      end

      it 'is unmet until the provider says the seller can be paid' do
        expect(requirement).not_to be_met_by_seller(seller)
      end

      it 'is met once the provider has enabled them' do
        seller.update!(payouts_enabled_at: Time.current)

        expect(requirement).to be_met_by_seller(seller)
      end

      # A seller whose documents expire stops being payable, and the checklist
      # should say so rather than reporting a state that has lapsed.
      it 'falls back to unmet when the provider withdraws the capability' do
        seller.update!(payouts_enabled_at: Time.current)
        expect(requirement).to be_met_by_seller(seller)

        seller.update!(payouts_enabled_at: nil)

        expect(requirement).not_to be_met_by_seller(seller.reload)
      end
    end
  end

  describe '#blocker' do
    # Nothing to explain when the provider has no opinion.
    it 'is silent under the record-only provider' do
      expect(requirement.blocker(seller)).to be_nil
    end

    context 'with a provider that reports on its own onboarding' do
      before do
        allow_any_instance_of(Spree::PayoutProvider::System).to receive(:onboarding_state).and_return(state)
        allow_any_instance_of(Spree::PayoutProvider::System).to receive(:onboarding_message).
          and_return('We could not read the document you uploaded.')
      end

      context 'when the provider wants something from the seller' do
        let(:state) { :action }

        it 'says so, with the provider’s own words' do
          expect(requirement.blocker(seller)).to eq(
            state: 'action', message: 'We could not read the document you uploaded.'
          )
        end
      end

      # Nobody can hurry this, so the panel says wait rather than offering a
      # button that would send the seller round a flow that cannot move.
      context 'when the provider is still checking' do
        let(:state) { :pending }

        it 'reports that it is waiting' do
          expect(requirement.blocker(seller)[:state]).to eq('pending')
        end
      end

      context 'when the provider has refused the seller' do
        let(:state) { :rejected }

        it 'reports the refusal' do
          expect(requirement.blocker(seller)[:state]).to eq('rejected')
        end
      end
    end
  end

  # A page of sellers would otherwise make one call to the payment provider
  # per row, which is the difference between a list that loads and one that
  # does not.
  describe 'on a listing' do
    before { requirement.prefer_cached = true }

    it 'answers from the stamp rather than asking the provider' do
      expect_any_instance_of(Spree::PayoutProvider::System).not_to receive(:onboarded?)
      seller.update!(payouts_enabled_at: Time.current)

      expect(requirement).to be_met_by_seller(seller)
    end

    it 'reads a seller with no stamp as unmet' do
      # Only a provider that actually moves money can refuse a seller; the
      # record-only one counts everybody payable.
      allow(Spree::PayoutProvider::System).to receive(:requires_payout_account?).and_return(true)
      seller.update!(payouts_enabled_at: nil)

      expect(requirement).not_to be_met_by_seller(seller)
    end

    # Which of the three states applies is the provider's to say, and a
    # listing is not asking — so it says nothing rather than guessing.
    it 'offers no explanation it would have to invent' do
      expect_any_instance_of(Spree::PayoutProvider::System).not_to receive(:onboarding_state)

      expect(requirement.blocker(seller)).to be_nil
    end
  end

  # The gates and a seller's own page ask the provider, whatever a list does.
  it 'asks the provider when nobody said a cached answer would do' do
    expect_any_instance_of(Spree::PayoutProvider::System).to receive(:onboarded?).and_return(true)

    expect(requirement).to be_met_by_seller(seller)
  end

  # A marketplace settling by hand should not have this forced on it.
  it 'is registered as a kind an operator may add' do
    expect(Spree.seller_requirements).to include(described_class)
  end

  it 'is not one of the defaults a store starts with' do
    expect(Spree::SellerRequirement::DEFAULT_KINDS).not_to include(described_class.to_s)
  end
end
