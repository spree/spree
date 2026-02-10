require 'spec_helper'

describe Spree::CurrencyHelper, type: :helper do
  let(:current_store) { create(:store, default_currency: 'EUR', supported_currencies: 'EUR,PLN,GBP') }

  before do
    allow(helper).to receive(:current_store).and_return(current_store)
    allow(helper).to receive(:current_currency).and_return('USD')
  end

  describe '#supported_currency_options' do
    it { expect(supported_currency_options).to contain_exactly(['Polish Złoty (PLN)', 'PLN'], ['British Pound (GBP)', 'GBP'], ['Euro (EUR)', 'EUR']) }
  end

  describe '#should_render_currency_dropdown?' do
    context 'store with multiple currencies' do
      it { expect(should_render_currency_dropdown?).to be_truthy }
    end

    context 'store with single currency' do
      let(:current_store) { create(:store, default_currency: 'EUR', supported_currencies: 'EUR') }

      it { expect(should_render_currency_dropdown?).to be_falsey }
    end
  end

  describe '#currency_symbol' do
    it { expect(currency_symbol('EUR')).to eq('€') }
  end

  describe '#currency_presentation' do
    it { expect(currency_presentation('EUR')).to eq(['Euro (EUR)', 'EUR']) }
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

  describe '#preferred_currencies' do
    it 'returns array of supported currencies from current store as `Money::Currency`' do
      expect(helper.preferred_currencies).to contain_exactly(Money::Currency.find('EUR'), Money::Currency.find('PLN'), Money::Currency.find('GBP'))
    end
  end
end
