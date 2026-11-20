require 'spec_helper'

RSpec.describe SpreeAdyen::Amounts do
  it 'converts two-decimal currencies to minor units' do
    expect(described_class.to_adyen(BigDecimal('10.99'), 'EUR')).to eq(1099)
  end

  it 'sends zero-decimal currencies in whole units' do
    expect(described_class.to_adyen(BigDecimal('1500'), 'JPY')).to eq(1500)
  end

  it 'sends three-decimal currencies in thousandths' do
    expect(described_class.to_adyen(BigDecimal('1.234'), 'KWD')).to eq(1234)
  end

  it "follows Adyen's table where it differs from ISO 4217" do
    expect(described_class.to_adyen(BigDecimal('1000'), 'ISK')).to eq(100_000)
    expect(described_class.to_adyen(BigDecimal('15000'), 'IDR')).to eq(15_000)
  end

  it 'raises, naming the rule, for an amount Adyen cannot represent' do
    expect { described_class.to_adyen(BigDecimal('15000.50'), 'IDR') }.
      to raise_error(described_class::UnsupportedAmount, 'Adyen takes IDR with 0 decimals, got 15000.5')
  end

  it 'raises for a currency Adyen does not take' do
    expect { described_class.to_adyen(BigDecimal('1'), 'XXX') }.to raise_error(described_class::UnsupportedAmount, /XXX/)
  end

  it 'reads amounts back' do
    expect(described_class.from_adyen(1099, 'EUR')).to eq(BigDecimal('10.99'))
    expect(described_class.from_adyen(1500, 'JPY')).to eq(BigDecimal('1500'))
  end

  it 'answers whether a currency is in the table' do
    expect(described_class.supported?('eur')).to be(true)
    expect(described_class.supported?('XXX')).to be(false)
  end

  describe 'the gateway' do
    let(:gateway) { create(:adyen_gateway) }

    it 'is not offered for a currency missing from the table' do
      order = build(:order, currency: 'XXX')
      allow(gateway).to receive(:available?).and_return(true)

      expect(gateway.available_for_order?(order)).to be(false)
    end
  end
end
