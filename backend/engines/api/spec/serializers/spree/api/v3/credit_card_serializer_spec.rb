require 'spec_helper'

RSpec.describe Spree::Api::V3::CreditCardSerializer do
  let(:store) { @default_store }
  let(:credit_card) do
    create(:credit_card,
           cc_type: 'visa',
           month: 12,
           year: 1.year.from_now.year,
           name: 'John Doe',
           default: true,
           gateway_payment_profile_id: 'pm_abc123')
  end
  let(:base_params) { { store: store, currency: store.default_currency } }

  subject { described_class.new(credit_card, params: base_params).to_h }

  it 'includes all expected attributes' do
    expect(subject.keys).to match_array(%w[
      id cc_type last_digits month year name default gateway_payment_profile_id
    ])
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(credit_card.prefixed_id)
  end

  it 'returns correct attribute values' do
    expect(subject['cc_type']).to eq('visa')
    expect(subject['last_digits']).to eq('1111')
    expect(subject['month']).to eq(12)
    expect(subject['year']).to eq(1.year.from_now.year)
    expect(subject['name']).to eq('John Doe')
    expect(subject['default']).to be true
    expect(subject['gateway_payment_profile_id']).to eq('pm_abc123')
  end

  context 'without gateway_payment_profile_id' do
    let(:credit_card) { create(:credit_card, gateway_payment_profile_id: nil) }

    it 'returns nil for gateway_payment_profile_id' do
      expect(subject['gateway_payment_profile_id']).to be_nil
    end
  end

  context 'without name' do
    let(:credit_card) do
      card = build(:credit_card, name: nil)
      card.save(validate: false)
      card
    end

    it 'returns nil for name' do
      expect(subject['name']).to be_nil
    end
  end
end
