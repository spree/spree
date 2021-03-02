require 'spec_helper'

describe Spree::CurrencyHelper, type: :helper do
  let(:current_store) { create(:store, default_currency: 'EUR', supported_currencies: 'EUR,PLN,GBP') }

  describe '#supported_currency_options' do
    it { expect(supported_currency_options).to contain_exactly('EUR', 'GBP', 'PLN') }
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
end
