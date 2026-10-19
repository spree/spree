require 'spec_helper'

RSpec.describe Spree::SalesContext do
  let(:store) { @default_store }
  let(:market) { create(:market, :eu, store: store) }

  describe 'validation' do
    it "takes the market's currency and default language when none is given" do
      context = described_class.new(store: store, market: market)

      expect(context).to be_valid
      expect(context.currency).to eq('EUR')
      expect(context.locale).to eq('de')
    end

    it "refuses a currency other than the market's" do
      context = described_class.new(store: store, market: market, currency: 'usd')

      expect(context).not_to be_valid
      expect(context.errors[:currency]).to be_present
    end

    it 'refuses a language the market does not offer' do
      context = described_class.new(store: store, market: market, locale: 'ja')

      expect(context).not_to be_valid
      expect(context.errors[:locale]).to be_present
    end
  end

  describe '#sellable_variants' do
    let(:product) { create(:product_in_stock, store: store) }
    let(:context) { described_class.new(store: store, market: market) }

    before do
      next if product.publication_for(store.default_channel)

      create(:product_publication, product: product, channel: store.default_channel)
    end

    it 'skips variants without a price in the currency' do
      expect(context.sellable_variants).not_to include(product.default_variant)
    end

    it 'offers variants priced in the currency by a price list only' do
      price_list = create(:price_list, store: store)
      create(:price, variant: product.default_variant, currency: 'EUR', amount: 10, price_list: price_list)

      expect(context.sellable_variants).to include(product.default_variant)
    end
  end
end
