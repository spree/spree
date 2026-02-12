# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::GiftCardSerializer do
  let(:store) { @default_store }
  let(:gift_card) do
    create(:gift_card,
           store: store,
           amount: 100.00,
           amount_used: 25.00,
           currency: 'USD',
           expires_at: Date.parse('2025-12-31'))
  end

  subject { described_class.serialize(gift_card) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(gift_card.prefixed_id)
      expect(subject[:code]).to eq(gift_card.code)
    end

    it 'includes state as string' do
      expect(subject[:state]).to be_a(String)
    end

    it 'includes amount fields' do
      expect(subject[:amount]).to eq(100.00)
      expect(subject[:amount_used]).to eq(25.00)
      expect(subject[:amount_authorized]).to be_present
      expect(subject[:amount_remaining]).to eq(75.00)
    end

    it 'includes currency' do
      expect(subject[:currency]).to eq('USD')
    end

    it 'includes foreign keys' do
      expect(subject[:store_id]).to eq(store.prefixed_id)
      expect(subject).to have_key(:user_id)
      expect(subject).to have_key(:gift_card_batch_id)
    end

    it 'includes dates' do
      expect(subject[:expires_at]).to eq('2025-12-31')
      expect(subject).to have_key(:redeemed_at)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end
  end
end
