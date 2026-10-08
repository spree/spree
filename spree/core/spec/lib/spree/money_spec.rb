require 'spec_helper'

describe Spree::Money do
  let(:store) { @default_store }
  let(:money)    { described_class.new(10) }
  let(:currency) { Money::Currency.new('USD') }

  it 'formats correctly' do
    expect(money.to_s).to eq('$10.00')
  end

  it 'can get cents' do
    expect(money.cents).to eq(1000)
  end

  it 'can get currency' do
    expect(money.currency).to eq(currency)
  end

  context 'with currency' do
    it 'passed in option' do
      money = described_class.new(10, with_currency: true, html_wrap: false)
      expect(money.to_s).to eq('$10.00 USD')
    end
  end

  context 'hide cents' do
    it 'hides cents suffix' do
      money = described_class.new(10, no_cents: true)
      expect(money.to_s).to eq('$10')
    end

    it 'shows cents suffix' do
      money = described_class.new(10)
      expect(money.to_s).to eq('$10.00')
    end
  end

  context 'currency parameter' do
    context 'when currency is specified in Canadian Dollars' do
      it 'uses the currency param over the global configuration' do
        money = described_class.new(10, currency: 'CAD', with_currency: true, html_wrap: false)
        expect(money.to_s).to eq('$10.00 CAD')
      end
    end

    context 'when currency is specified in Japanese Yen' do
      it 'uses the currency param over the global configuration' do
        money = described_class.new(100, currency: 'JPY', html_wrap: false)
        expect(money.to_s).to eq('¥100')
      end
    end
  end

  context 'format' do
    it 'passed in option' do
      money = described_class.new(10, format: '%n %u', html_wrap: false)
      expect(money.to_s).to eq('10.00 $')
    end
  end

  context 'sign before symbol' do
    it 'defaults to -$10.00' do
      money = described_class.new(-10)
      expect(money.to_s).to eq('-$10.00')
    end

    it 'passed in option' do
      money = described_class.new(-10, sign_before_symbol: false)
      expect(money.to_s).to eq('$-10.00')
    end
  end

  context 'JPY' do
    before do
      allow_any_instance_of(Spree::Store).to receive(:default_currency).and_return('JPY')
    end

    it 'formats correctly' do
      money = described_class.new(1000, html_wrap: false)
      expect(money.to_s).to eq('¥1,000')
    end
  end

  context 'DKK' do
    before do
      allow_any_instance_of(Spree::Store).to receive(:default_currency).and_return('DKK')
    end

    it 'formats correctly' do
      money = described_class.new(1000, html_wrap: false)
      expect(money.to_s).to eq('1,000.00 kr.')
    end
  end

  context 'EUR' do
    before do
      allow_any_instance_of(Spree::Store).to receive(:default_currency).and_return('EUR')
    end

    # Regression test for #2634
    it 'formats as plain by default' do
      money = described_class.new(10, format: '%n %u')
      expect(money.to_s).to eq('10.00 €')
    end

    # rubocop:disable Style/AsciiComments
    it 'formats as HTML if asked (nicely) to' do
      money = described_class.new(10, format: '%n %u')
      expect(money.to_html).to eq('10.00&nbsp;€')
    end

    it 'formats as HTML with currency' do
      money = described_class.new(10, format: '%n %u', with_currency: true)
      expect(money.to_html).to eq('10.00&nbsp;€ EUR')
    end
    # rubocop:enable Style/AsciiComments
  end

  context 'Money formatting rules' do
    before do
      allow_any_instance_of(Spree::Store).to receive(:default_currency).and_return('EUR')
    end

    after do
      described_class.default_formatting_rules.delete(:decimal_mark)
      described_class.default_formatting_rules.delete(:thousands_separator)
    end

    let(:money) { described_class.new(10) }

    describe '#decimal_mark' do
      it 'uses decimal mark set in Monetize gem' do
        expect(money.decimal_mark).to eq('.')
      end

      it 'favors decimal mark set in default_formatting_rules' do
        described_class.default_formatting_rules[:decimal_mark] = ','
        expect(money.decimal_mark).to eq(',')
      end

      it 'favors decimal mark passed in as a parameter on initialization' do
        money = described_class.new(10, decimal_mark: ',')
        expect(money.decimal_mark).to eq(',')
      end
    end

    describe '#thousands_separator' do
      it 'uses thousands separator set in Monetize gem' do
        expect(money.thousands_separator).to eq(',')
      end

      it 'favors decimal mark set in default_formatting_rules' do
        described_class.default_formatting_rules[:thousands_separator] = '.'
        expect(money.thousands_separator).to eq('.')
      end

      it 'favors decimal mark passed in as a parameter on initialization' do
        money = described_class.new(10, thousands_separator: '.')
        expect(money.thousands_separator).to eq('.')
      end
    end
  end

  describe '#amount_in_cents' do
    %w[USD JPY KRW].each do |currency_name|
      context "when currency is #{currency_name}" do
        let(:money) { described_class.new(100, currency: currency_name) }

        it { expect(money.amount_in_cents).to eq(10000) }
      end
    end

    it 'counts hundredths without float error' do
      expect(described_class.new(BigDecimal('1.15')).amount_in_cents).to eq(115)
      expect(described_class.new(BigDecimal('0.29')).amount_in_cents).to eq(29)
      expect(described_class.new(BigDecimal('1234567.89')).amount_in_cents).to eq(123_456_789)
    end
  end

  describe '#as_json' do
    let(:options) { double('options') }

    it 'returns the expected string' do
      money = described_class.new(10)
      expect(money.as_json(options)).to eq('$10.00')
    end
  end

  # Apportionment divides money in whole minor units, because integers divide
  # exactly and can be made to add back up to the amount they came from.
  describe Spree::Money::Rounding do
    describe '.to_minor_units' do
      it 'counts cents for a currency written in them' do
        expect(described_class.to_minor_units(BigDecimal('12.34'), 'USD')).to eq(1234)
      end

      it 'counts whole yen, which are written without decimals' do
        expect(described_class.to_minor_units(BigDecimal('1234'), 'JPY')).to eq(1234)
      end

      it 'counts thousandths for a three-decimal currency' do
        expect(described_class.to_minor_units(BigDecimal('1.234'), 'BHD')).to eq(1234)
      end

      it 'rounds half up rather than truncating' do
        expect(described_class.to_minor_units(BigDecimal('0.005'), 'USD')).to eq(1)
      end
    end

    describe '.precision' do
      it 'follows ISO 4217 where the Money gem does not' do
        expect(described_class.precision('HUF')).to eq(2)
        expect(described_class.precision('MGA')).to eq(2)
      end

      it 'reads the exponent of zero-, two- and three-decimal currencies' do
        expect(%w[JPY USD KWD].map { |code| described_class.precision(code) }).to eq([0, 2, 3])
      end

      it 'falls back to two places for an unknown code' do
        expect(described_class.precision('ZZZ')).to eq(2)
      end
    end

    describe '.to_currency' do
      it 'rounds half up by default' do
        expect(described_class.to_currency(BigDecimal('2.345'), 'USD')).to eq(BigDecimal('2.35'))
      end

      it 'rounds with the mode a caller asks for' do
        expect(described_class.to_currency(BigDecimal('2.345'), 'USD', mode: :half_even)).to eq(BigDecimal('2.34'))
      end
    end

    describe '.parse_canonical' do
      it 'reads a canonical string exactly' do
        expect(described_class.parse_canonical('1234567.89', 'USD')).to eq(BigDecimal('1234567.89'))
        expect(described_class.parse_canonical('-0.29', 'USD')).to eq(BigDecimal('-0.29'))
      end

      it 'passes nil through' do
        expect(described_class.parse_canonical(nil, 'USD')).to be_nil
      end

      [19.99, 20, '1,99', '1.234,56', ' 5', '+5', '1e3', '', '.5', '5.'].each do |value|
        it "rejects #{value.inspect}" do
          expect { described_class.parse_canonical(value, 'USD') }.to raise_error(Spree::Money::InvalidFormat)
        end
      end

      it 'rejects more decimals than the currency has' do
        expect { described_class.parse_canonical('19.999', 'USD') }.to raise_error(Spree::Money::InvalidFormat)
        expect { described_class.parse_canonical('100.5', 'JPY') }.to raise_error(Spree::Money::InvalidFormat)
        expect(described_class.parse_canonical('1.500', 'KWD')).to eq(BigDecimal('1.5'))
      end

      it 'allows a unit price four decimals' do
        expect(described_class.parse_canonical('0.0125', 'USD', unit_price: true)).to eq(BigDecimal('0.0125'))
        expect { described_class.parse_canonical('0.01255', 'USD', unit_price: true) }.to raise_error(Spree::Money::InvalidFormat)
      end
    end

    describe '.format' do
      it "writes exactly the currency's decimal places" do
        expect(described_class.format(BigDecimal('10'), 'USD')).to eq('10.00')
        expect(described_class.format(BigDecimal('1.5'), 'KWD')).to eq('1.500')
        expect(described_class.format(BigDecimal('100'), 'JPY')).to eq('100')
        expect(described_class.format(BigDecimal('-0.5'), 'USD')).to eq('-0.50')
      end

      it 'keeps a unit price below the minor unit and drops zeros beyond it' do
        expect(described_class.format(BigDecimal('0.0125'), 'USD', unit_price: true)).to eq('0.0125')
        expect(described_class.format(BigDecimal('19.9900'), 'USD', unit_price: true)).to eq('19.99')
        expect(described_class.format(BigDecimal('100'), 'JPY', unit_price: true)).to eq('100')
        expect(described_class.format(BigDecimal('100.5'), 'JPY', unit_price: true)).to eq('100.5')
      end

      it 'passes nil through' do
        expect(described_class.format(nil, 'USD')).to be_nil
      end
    end

    describe '.format_decimal' do
      it 'drops trailing zeros' do
        expect(described_class.format_decimal(BigDecimal('0.23000'))).to eq('0.23')
        expect(described_class.format_decimal(BigDecimal('23.00'))).to eq('23')
        expect(described_class.format_decimal(BigDecimal('100'))).to eq('100')
        expect(described_class.format_decimal(BigDecimal('0'))).to eq('0')
      end
    end

    describe '.from_minor_units' do
      it 'is the inverse for each currency' do
        { 'USD' => '12.34', 'JPY' => '1234', 'BHD' => '1.234' }.each do |currency, amount|
          units = described_class.to_minor_units(BigDecimal(amount), currency)

          expect(described_class.from_minor_units(units, currency)).to eq(BigDecimal(amount))
        end
      end
    end
  end
end
