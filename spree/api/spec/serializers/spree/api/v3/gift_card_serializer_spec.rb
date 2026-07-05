require 'spec_helper'

RSpec.describe Spree::Api::V3::GiftCardSerializer do
  let(:store) { @default_store }
  let(:gift_card) { create(:gift_card, store: store, amount: 100, amount_used: 25) }
  let(:base_params) { { store: store, currency: store.default_currency } }

  subject { described_class.new(gift_card, params: base_params).to_h }

  it 'includes all expected attributes' do
    expect(subject.keys).to match_array(%w[
      id code status currency
      amount amount_used amount_authorized amount_remaining
      display_amount display_amount_used display_amount_remaining
      expires_at redeemed_at expired active
    ])
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(gift_card.prefixed_id)
  end

  it 'returns the uppercased code' do
    expect(subject['code']).to eq(gift_card.code.upcase)
  end

  it 'returns correct amounts as floats' do
    expect(subject['amount']).to eq(100.0)
    expect(subject['amount_used']).to eq(25.0)
    expect(subject['amount_authorized']).to eq(0.0)
    expect(subject['amount_remaining']).to eq(75.0)
  end

  it 'returns display amounts as strings' do
    expect(subject['display_amount']).to be_a(String)
    expect(subject['display_amount_used']).to be_a(String)
    expect(subject['display_amount_remaining']).to be_a(String)
  end

  it 'returns currency' do
    expect(subject['currency']).to eq(gift_card.currency)
  end

  it 'returns status' do
    expect(subject['status']).to eq('active')
  end

  it 'returns active as true for active card' do
    expect(subject['active']).to be true
    expect(subject['expired']).to be false
  end

  it 'returns nil for expires_at and redeemed_at when not set' do
    expect(subject['expires_at']).to be_nil
    expect(subject['redeemed_at']).to be_nil
  end

  it 'does not include timestamps in Store API' do
    expect(subject).not_to have_key('created_at')
    expect(subject).not_to have_key('updated_at')
  end

  context 'with expired gift card' do
    let(:gift_card) { create(:gift_card, :expired, store: store, amount: 50) }

    it 'returns expired status' do
      expect(subject['status']).to eq('expired')
      expect(subject['expired']).to be true
      expect(subject['active']).to be false
    end

    it 'returns expires_at as ISO 8601' do
      expect(subject['expires_at']).to eq(gift_card.expires_at.iso8601)
    end
  end

  context 'with redeemed gift card' do
    let(:gift_card) { create(:gift_card, :redeemed, store: store, amount: 50) }

    it 'returns redeemed status' do
      expect(subject['status']).to eq('redeemed')
    end

    it 'returns redeemed_at as ISO 8601' do
      expect(subject['redeemed_at']).to eq(gift_card.redeemed_at.iso8601)
    end

    it 'returns zero remaining amount' do
      expect(subject['amount_remaining']).to eq(0.0)
    end
  end

  context 'with partially redeemed gift card' do
    let(:gift_card) { create(:gift_card, store: store, state: :partially_redeemed, amount: 100, amount_used: 40) }

    it 'returns partially_redeemed status' do
      expect(subject['status']).to eq('partially_redeemed')
    end

    it 'returns correct remaining amount' do
      expect(subject['amount_remaining']).to eq(60.0)
    end
  end
end
