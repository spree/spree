require 'spec_helper'

RSpec.describe Spree::SellerPayouts::Complete do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }
  let(:payout) { create(:seller_payout, seller: seller, amount: 40) }

  describe 'recording that the money landed' do
    it 'completes the settlement' do
      expect(described_class.call(seller_payout: payout)).to be_success
      expect(payout.reload).to be_completed
    end

    it "keeps the provider's own reference for it" do
      described_class.call(seller_payout: payout, reference: 'BACS-9912')

      expect(payout.reload.reference).to eq('BACS-9912')
    end

    it 'debits the balance, which is what completing means' do
      create(:seller_transfer, :completed, seller: seller, amount: 40, payout: payout)

      expect { described_class.call(seller_payout: payout) }.
        to change { seller.balance('USD') }.from(40).to(0)
    end
  end

  # An operator marking a bank transfer sent can race the provider's own
  # webhook saying the same thing. Both pass a plain read of the status.
  describe 'when it is recorded twice' do
    it 'announces the settlement once' do
      described_class.call(seller_payout: payout)

      expect_any_instance_of(Spree::SellerPayout).not_to receive(:publish_event)

      described_class.call(seller_payout: payout)
    end

    it 'announces it once even when both callers read it as unsettled' do
      stale = Spree::SellerPayout.find(payout.id)
      described_class.call(seller_payout: payout)

      # `stale` still believes the payout is pending, which is exactly what a
      # racing webhook holds.
      expect_any_instance_of(Spree::SellerPayout).not_to receive(:publish_event)

      described_class.call(seller_payout: stale)
    end

    it "does not let a blank second caller wipe the first one's reference" do
      described_class.call(seller_payout: payout, reference: 'BACS-9912')
      described_class.call(seller_payout: Spree::SellerPayout.find(payout.id))

      expect(payout.reload.reference).to eq('BACS-9912')
    end
  end

  # A settlement whose outcome was never established holds no reference of its
  # own, so a webhook matches it by the id Spree sent rather than the
  # provider's. A redelivered event can therefore name a reference already
  # filed against a different settlement.
  describe 'when the reference belongs to another settlement' do
    let!(:already_filed) do
      create(:seller_payout, seller: seller, currency: 'USD', reference: 'po_X', status: 'completed')
    end
    let(:stuck) do
      create(:seller_payout, seller: seller, currency: 'USD', reference: nil, status: 'unresolved')
    end

    it 'does not blow up on the unique index' do
      expect { described_class.call(seller_payout: stuck, reference: 'po_X') }.not_to raise_error
    end

    # Completing it would record one movement as two settlements.
    it 'leaves it for a person to reconcile' do
      described_class.call(seller_payout: stuck, reference: 'po_X')

      expect(stuck.reload).to be_unresolved
      expect(stuck.reference).to be_nil
    end

    it 'leaves the settlement that already holds the reference alone' do
      described_class.call(seller_payout: stuck, reference: 'po_X')

      expect(already_filed.reload.reference).to eq('po_X')
    end
  end
end
