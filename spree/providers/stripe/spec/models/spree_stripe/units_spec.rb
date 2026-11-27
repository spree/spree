require 'spec_helper'

RSpec.describe SpreeStripe::Units do
  {
    ['19.99', 'USD'] => 1999,
    ['1000', 'JPY'] => 1000,
    ['1.500', 'KWD'] => 1500,
    ['5', 'ISK'] => 500,
    ['5', 'UGX'] => 500,
    ['1500.50', 'HUF'] => 150_050
  }.each do |(amount, currency), units|
    it "sends #{amount} #{currency} as #{units}" do
      expect(described_class.to_stripe(BigDecimal(amount), currency)).to eq(units)
      expect(described_class.from_stripe(units, currency)).to eq(BigDecimal(amount))
    end
  end

  it 'refuses a three-decimal amount Stripe would refuse' do
    expect { described_class.to_stripe(BigDecimal('1.505'), 'KWD') }.to raise_error(described_class::UnsupportedAmount, /0.010/)
  end

  it 'refuses a forint payout in fractions, but charges one' do
    expect { described_class.to_stripe(BigDecimal('1500.50'), 'HUF', payout: true) }.to raise_error(described_class::UnsupportedAmount)
    expect(described_class.to_stripe(BigDecimal('1500'), 'HUF', payout: true)).to eq(150_000)
  end

  it 'takes a Spree::Money' do
    expect(described_class.to_stripe(Spree::Money.new(BigDecimal('1000'), currency: 'JPY'), 'JPY')).to eq(1000)
  end

  it 'rounds a computed amount down to the step Stripe moves the currency in' do
    expect(described_class.floor_to_step(16_480, 'KWD')).to eq(16_480)
    expect(described_class.floor_to_step(16_487, 'KWD')).to eq(16_480)
    expect(described_class.floor_to_step(150_050, 'HUF', payout: true)).to eq(150_000)
    expect(described_class.floor_to_step(150_050, 'HUF')).to eq(150_050)
    expect(described_class.floor_to_step(1_250, 'ISK')).to eq(1_200)
    expect(described_class.floor_to_step(5_397, 'USD')).to eq(5_397)
  end
end
