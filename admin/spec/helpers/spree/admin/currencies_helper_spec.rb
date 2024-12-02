require 'spec_helper'

RSpec.describe Spree::Admin::CurrenciesHelper, type: :helper do
  let(:store) { create(:store, supported_currencies: 'USD,EUR,GBP') }

  before do
    allow(helper).to receive(:current_store).and_return(store)
    allow(helper).to receive(:current_currency).and_return('USD')
  end

  describe '#preferred_currencies' do
    it 'returns array of supported currencies from current store as `Money::Currency`' do
      expect(helper.preferred_currencies).to eq([Money::Currency.find('USD'), Money::Currency.find('EUR'), Money::Currency.find('GBP')])
    end
  end

  describe '#currency_money' do
    it 'returns Money::Currency instance for given currency' do
      expect(helper.currency_money('EUR')).to be_a(Money::Currency)
      expect(helper.currency_money('EUR').iso_code).to eq('EUR')
    end

    it 'uses current_currency when no argument is provided' do
      expect(helper.currency_money.iso_code).to eq('USD')
    end
  end

  describe '#currency_symbol' do
    it 'returns symbol for given currency' do
      expect(helper.currency_symbol('USD')).to eq('$')
      expect(helper.currency_symbol('EUR')).to eq('€')
    end

    it 'uses current_currency when no argument is provided' do
      expect(helper.currency_symbol).to eq('$')
    end
  end
end
