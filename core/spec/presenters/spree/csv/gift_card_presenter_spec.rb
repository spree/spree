require 'spec_helper'

RSpec.describe Spree::CSV::GiftCardPresenter, type: :model do
  let(:store) { create(:store) }
  let(:user) { create(:user, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }
  let(:gift_card) do
    create(:gift_card,
           code: 'ABC123',
           amount: 50.00,
           amount_used: 10.00,
           currency: 'USD',
           state: 'active',
           expires_at: Date.new(2025, 12, 31),
           user: user,
           store: store)
  end
  let(:presenter) { described_class.new(gift_card) }

  describe '#call' do
    subject { presenter.call }

    it 'returns the correct CSV data' do
      expect(subject).to be_an(Array)
      expect(subject.length).to eq(12)
      expect(subject[0]).to eq('ABC123')           # Code
      expect(subject[4]).to eq('USD')              # Currency
      expect(subject[5]).to eq('active')           # Status
      expect(subject[6]).to eq('2025-12-31')       # Expires At
      expect(subject[7]).to eq('john@example.com') # Customer Email
      expect(subject[8]).to eq('John')             # Customer First Name
      expect(subject[9]).to eq('Doe')              # Customer Last Name
    end

    context 'when gift card has no user' do
      let(:gift_card) { create(:gift_card, user: nil, store: store) }

      it 'returns nil for customer fields' do
        expect(subject[7]).to be_nil  # Customer Email
        expect(subject[8]).to be_nil  # Customer First Name
        expect(subject[9]).to be_nil  # Customer Last Name
      end
    end

    context 'when gift card has no expiration date' do
      let(:gift_card) { create(:gift_card, expires_at: nil, store: store) }

      it 'returns nil for expires at' do
        expect(subject[6]).to be_nil  # Expires At
      end
    end
  end

  describe 'HEADERS' do
    it 'has the correct headers' do
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
      expect(Spree::CSV::GiftCardPresenter::HEADERS).to eq(expected_headers)
    end
  end
end