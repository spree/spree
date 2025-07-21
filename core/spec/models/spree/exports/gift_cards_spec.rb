require 'spec_helper'

RSpec.describe Spree::Exports::GiftCards, type: :model do
  let(:store) { create(:store) }
  let(:admin_user) { create(:admin_user) }
  let(:export) { described_class.new(store: store, user: admin_user) }

  before do
    # Stub the ability to allow access to gift cards
    allow_any_instance_of(Spree::Ability).to receive(:can?).with(:read, Spree::GiftCard).and_return(true)
    allow_any_instance_of(Spree::Ability).to receive(:cannot?).and_return(false)
  end

  describe '#scope' do
    let!(:gift_card_1) { create(:gift_card, store: store) }
    let!(:gift_card_2) { create(:gift_card, store: store) }

    context 'when search_params is nil' do
      it 'includes all gift cards for the store' do
        expect(export.scope).to include(gift_card_1)
        expect(export.scope).to include(gift_card_2)
      end
    end

    context 'when search_params filters by status' do
      let!(:active_gift_card) { create(:gift_card, store: store, state: 'active') }
      let!(:redeemed_gift_card) { create(:gift_card, store: store, state: 'redeemed') }
      let(:export) { described_class.new(store: store, user: admin_user, search_params: { status_eq: 'active' }) }

      it 'includes only active gift cards' do
        expect(export.scope).to include(active_gift_card)
        expect(export.scope).not_to include(redeemed_gift_card)
      end
    end
  end

  describe '#csv_headers' do
    it 'returns the correct headers' do
      expected_headers = [
        'Code',
        'Amount',
        'Amount Used',
        'Amount Remaining',
        'Currency',
        'Status',
        'Expires At',
        'Customer Email',
        'Customer First Name',
        'Customer Last Name',
        'Created At',
        'Updated At'
      ]
      expect(export.csv_headers).to eq(expected_headers)
    end
  end
end