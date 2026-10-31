require 'spec_helper'

RSpec.describe SpreePaypalCheckout::Amounts do
  describe '.to_paypal' do
    it 'writes two-decimal currencies with both decimals' do
      expect(described_class.to_paypal(BigDecimal('19.9'), 'USD')).to eq('19.90')
      expect(described_class.to_paypal(BigDecimal('20'), 'eur')).to eq('20.00')
    end

    it 'writes HUF, JPY and TWD in whole units' do
      expect(described_class.to_paypal(BigDecimal('2000'), 'JPY')).to eq('2000')
      expect(described_class.to_paypal(BigDecimal('1500.00'), 'HUF')).to eq('1500')
      expect(described_class.to_paypal(BigDecimal('300'), 'TWD')).to eq('300')
    end

    it 'takes a Spree::Money' do
      expect(described_class.to_paypal(Spree::Money.new(BigDecimal('12.5'), currency: 'USD'), 'USD')).to eq('12.50')
    end

    it 'raises for a JPY amount with a fraction instead of rounding it' do
      expect { described_class.to_paypal(BigDecimal('100.5'), 'JPY') }.
        to raise_error(described_class::UnsupportedAmount, 'PayPal takes JPY only in whole units, got 100.5')
    end

    it 'raises for HUF with a fraction, which ISO writes with decimals' do
      expect { described_class.to_paypal(BigDecimal('99.99'), 'HUF') }.
        to raise_error(described_class::UnsupportedAmount, /HUF only in whole units/)
    end

    it 'raises for more decimals than the currency has' do
      expect { described_class.to_paypal(BigDecimal('10.005'), 'USD') }.
        to raise_error(described_class::UnsupportedAmount, 'PayPal takes USD only to 2 decimal places, got 10.005')
    end

    it 'raises for a currency PayPal does not take' do
      expect { described_class.to_paypal(BigDecimal('10'), 'KWD') }.
        to raise_error(described_class::UnsupportedAmount, 'PayPal does not take KWD')
    end

    it 'is a gateway error' do
      expect(described_class::UnsupportedAmount.ancestors).to include(Spree::Core::GatewayError)
    end
  end

  describe '.payable?' do
    it { expect(described_class.payable?(BigDecimal('1234'), 'TWD')).to be(true) }
    it { expect(described_class.payable?(BigDecimal('1234.5'), 'TWD')).to be(false) }
    it { expect(described_class.payable?(BigDecimal('10'), 'INR')).to be(false) }
  end

  describe '.supported_currency?' do
    it { expect(described_class.supported_currency?('usd')).to be(true) }
    it { expect(described_class.supported_currency?('INR')).to be(false) }
  end

  describe '.to_paypal_money' do
    it 'builds the SDK money model' do
      money = described_class.to_paypal_money(BigDecimal('5'), 'usd')

      expect(money.to_hash).to eq('currency_code' => 'USD', 'value' => '5.00')
    end
  end
end
