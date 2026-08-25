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

  # A marketplace settling by hand should not have this forced on it.
  it 'is registered as a kind an operator may add' do
    expect(Spree.seller_requirements).to include(described_class)
  end

  it 'is not one of the defaults a store starts with' do
    expect(Spree::SellerRequirement::DEFAULT_KINDS).not_to include(described_class.to_s)
  end
end
