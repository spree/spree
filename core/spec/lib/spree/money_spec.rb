require 'spec_helper'

describe Spree::Money do
  before do
    configure_spree_preferences do |config|
      config.currency = 'USD'
    end
  end

  it 'formats correctly' do
    money = described_class.new(10)
    expect(money.to_s).to eq('$10.00')
  end

  it 'can get cents' do
    money = described_class.new(10)
    expect(money.cents).to eq(1000)
  end

  context 'with currency' do
    it 'passed in option' do
      money = described_class.new(10, with_currency: true, html: false)
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
        money = described_class.new(10, currency: 'CAD', with_currency: true, html: false)
        expect(money.to_s).to eq('$10.00 CAD')
      end
    end

    context 'when currency is specified in Japanese Yen' do
      it 'uses the currency param over the global configuration' do
        money = described_class.new(100, currency: 'JPY', html: false)
        expect(money.to_s).to eq('¥100')
      end
    end
  end

  context 'symbol positioning' do
    it 'passed in option' do
      money = described_class.new(10, symbol_position: :after, html: false)
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
      configure_spree_preferences do |config|
        config.currency = 'JPY'
      end
    end

    it 'formats correctly' do
      money = described_class.new(1000, html: false)
      expect(money.to_s).to eq('¥1,000')
    end
  end

  context 'EUR' do
    before do
      configure_spree_preferences do |config|
        config.currency = 'EUR'
      end
    end

    # Regression test for #2634
    it 'formats as plain by default' do
      money = described_class.new(10, symbol_position: :after)
      expect(money.to_s).to eq('10.00 €')
    end

    # rubocop:disable Style/AsciiComments
    it 'formats as HTML if asked (nicely) to' do
      money = described_class.new(10, symbol_position: :after)
      # The HTML'ified version of "10.00 €"
      expect(money.to_html).to eq('10.00&nbsp;&#x20AC;')
    end

    it 'formats as HTML with currency' do
      money = described_class.new(10, symbol_position: :after, with_currency: true)
      # The HTML'ified version of "10.00 €"
      expect(money.to_html).to eq('10.00&nbsp;&#x20AC; <span class="currency">EUR</span>')
    end
    # rubocop:enable Style/AsciiComments
  end

  context 'Money formatting rules' do
    before do
      configure_spree_preferences do |config|
        config.currency = 'EUR'
      end
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

  describe '#as_json' do
    let(:options) { double('options') }

    it 'returns the expected string' do
      money = described_class.new(10)
      expect(money.as_json(options)).to eq('$10.00')
    end
  end
end
