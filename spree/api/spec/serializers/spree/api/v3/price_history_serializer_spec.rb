require 'spec_helper'

RSpec.describe Spree::Api::V3::PriceHistorySerializer do
  let(:store) { @default_store }
  let(:variant) { create(:variant) }
  let(:price) { variant.default_price }
  let(:base_params) { { store: store, currency: 'USD' } }

  let(:price_history) do
    create(:price_history, price: price, variant: variant, amount: 9.99, currency: 'USD', recorded_at: 10.days.ago)
  end

  subject { described_class.new(price_history, params: base_params).to_h }

  it 'includes amount fields' do
    expect(subject).to include(
      'amount' => '9.99'.to_d,
      'amount_in_cents' => 999,
      'currency' => 'USD'
    )
  end

  it 'includes display_amount' do
    expect(subject['display_amount']).to eq('$9.99')
  end

  it 'includes recorded_at as ISO8601' do
    expect(subject['recorded_at']).to eq(price_history.recorded_at.iso8601)
  end

  context 'with a different currency' do
    let(:price_history) do
      create(:price_history, price: price, variant: variant, amount: 19.99, currency: 'EUR', recorded_at: 5.days.ago)
    end

    it 'uses the correct currency for display' do
      expect(subject['currency']).to eq('EUR')
      expect(subject['amount']).to eq('19.99'.to_d)
    end
  end
end

RSpec.describe Spree::Api::V3::Admin::PriceHistorySerializer do
  let(:store) { @default_store }
  let(:variant) { create(:variant) }
  let(:price) { variant.default_price }
  let(:base_params) { { store: store, currency: 'USD' } }

  let(:price_history) do
    create(:price_history, price: price, variant: variant, amount: 9.99, compare_at_amount: 14.99, currency: 'USD', recorded_at: 10.days.ago)
  end

  subject { described_class.new(price_history, params: base_params).to_h }

  it 'includes store serializer fields' do
    expect(subject).to include(
      'amount' => '9.99'.to_d,
      'amount_in_cents' => 999,
      'currency' => 'USD',
      'display_amount' => '$9.99'
    )
  end

  it 'includes admin-only fields' do
    expect(subject['variant_id']).to eq(variant.prefixed_id)
    expect(subject['price_id']).to eq(price.prefixed_id)
    expect(subject['compare_at_amount']).to eq('14.99'.to_d)
    expect(subject['created_at']).to be_present
  end
end
