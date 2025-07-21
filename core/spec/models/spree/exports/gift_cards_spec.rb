require 'spec_helper'

RSpec.describe Spree::Exports::GiftCards, type: :model do
  let(:store) { @default_store }
  let(:admin_user) { create(:admin_user) }
  let(:export) { described_class.new(store: store, user: admin_user) }

  describe '#records_to_export' do
    context 'when search_params is nil' do
      let!(:gift_card_1) { create(:gift_card, store: store) }
      let!(:gift_card_2) { create(:gift_card, store: store) }

      it 'includes all gift cards for the store' do
        expect(export.records_to_export).to include(gift_card_1)
        expect(export.records_to_export).to include(gift_card_2)
      end
    end

    context 'when search_params filters by status' do
      let!(:active_gift_card) { create(:gift_card, store: store) }
      let!(:redeemed_gift_card) { create(:gift_card, :redeemed, store: store) }
      let(:export) { described_class.new(store: store, user: admin_user, search_params: { active: true }) }

      it 'includes only active gift cards' do
        expect(export.records_to_export).to include(active_gift_card)
        expect(export.records_to_export).not_to include(redeemed_gift_card)
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
