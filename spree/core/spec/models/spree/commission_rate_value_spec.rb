require 'spec_helper'

RSpec.describe Spree::CommissionRateValue do
  let(:store) { @default_store }
  let(:rate) { create(:commission_rate, store: store) }

  it 'rejects a cap below the floor' do
    value = rate.commission_rate_values.build(currency: 'USD', min_amount: 10, max_amount: 5)

    expect(value).not_to be_valid
    expect(value.errors[:max_amount]).to be_present
  end

  it 'accepts a floor with no cap, and a cap with no floor' do
    expect(rate.commission_rate_values.build(currency: 'USD', min_amount: 5)).to be_valid
    expect(rate.commission_rate_values.build(currency: 'EUR', max_amount: 5)).to be_valid
  end

  it 'holds one row per currency per rate' do
    rate.commission_rate_values.create!(currency: 'USD', amount: 5)
    duplicate = rate.commission_rate_values.build(currency: 'USD', amount: 6)

    expect(duplicate).not_to be_valid
  end

  # Currencies are compared against the sale's, so a lowercase write would
  # otherwise silently never match.
  it 'stores the currency uppercased' do
    value = rate.commission_rate_values.create!(currency: 'usd', amount: 5)

    expect(value.currency).to eq('USD')
  end

  describe '#bounded?' do
    it 'is true only when a floor or a cap is set' do
      expect(rate.commission_rate_values.build(currency: 'USD', amount: 5)).not_to be_bounded
      expect(rate.commission_rate_values.build(currency: 'USD', min_amount: 1)).to be_bounded
      expect(rate.commission_rate_values.build(currency: 'USD', max_amount: 9)).to be_bounded
    end
  end
end
