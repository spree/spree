require 'spec_helper'

RSpec.describe Spree::Api::V3::StoreCreditSerializer do
  let(:store) { @default_store }
  let(:store_credit) { create(:store_credit, amount: 100.00, currency: 'USD', store: store) }
  let(:base_params) { { store: store, currency: store.default_currency } }

  subject { described_class.new(store_credit, params: base_params).to_h }

  it 'includes all expected attributes' do
    expect(subject.keys).to match_array(%w[
      id amount amount_used amount_remaining
      display_amount display_amount_used display_amount_remaining
      currency
    ])
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(store_credit.prefixed_id)
  end

  it 'returns correct attribute values' do
    expect(subject['amount']).to eq('100.0')
    expect(subject['amount_used']).to eq('0.0')
    expect(subject['amount_remaining']).to eq('100.0')
    expect(subject['display_amount']).to be_present
    expect(subject['display_amount_used']).to be_present
    expect(subject['display_amount_remaining']).to be_present
    expect(subject['currency']).to eq('USD')
  end

  context 'with partially used credit' do
    before do
      store_credit.update!(amount_used: 40.00)
    end

    it 'returns correct amounts' do
      expect(subject['amount']).to eq('100.0')
      expect(subject['amount_used']).to eq('40.0')
      expect(subject['amount_remaining']).to eq('60.0')
    end
  end
end
