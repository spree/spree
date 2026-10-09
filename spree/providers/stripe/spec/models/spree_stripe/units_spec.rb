require 'spec_helper'

RSpec.describe SpreeStripe::Units do
  {
    ['19.99', 'USD'] => 1999,
    ['1000', 'JPY'] => 1000,
    ['1.505', 'KWD'] => 1505,
    ['5', 'ISK'] => 500,
    ['5', 'UGX'] => 500,
    ['1500.50', 'HUF'] => 150_050
  }.each do |(amount, currency), units|
    it "sends #{amount} #{currency} as #{units}" do
      expect(described_class.to_stripe(BigDecimal(amount), currency)).to eq(units)
      expect(described_class.from_stripe(units, currency)).to eq(BigDecimal(amount))
    end
  end

  it 'takes a Spree::Money' do
    expect(described_class.to_stripe(Spree::Money.new(BigDecimal('1000'), currency: 'JPY'), 'JPY')).to eq(1000)
  end
end
