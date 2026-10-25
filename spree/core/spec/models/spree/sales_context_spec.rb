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

    it 'picks a market selling the requested currency when none is chosen' do
      market
      context = described_class.new(store: store, currency: 'eur')

      expect(context.market).to eq(market)
      expect(context).to be_valid
    end

    it 'refuses a currency no market sells' do
      market
      context = described_class.new(store: store, currency: 'JPY')

      expect(context).not_to be_valid
      expect(context.errors[:currency]).to be_present
    end

    it 'refuses a language the market does not offer' do
      context = described_class.new(store: store, market: market, locale: 'ja')

      expect(context).not_to be_valid
      expect(context.errors[:locale]).to be_present
    end
  end

  describe '#company' do
    let(:customer) { create(:user) }

    it "keeps a placed sale's company, even none" do
      expect(Spree::Company).not_to receive(:sole_standing_for)

      expect(described_class.new(store: store, customer: customer, resolve_company: false).company).to be_nil
    end

    it 'looks up the company the customer stands in for a new sale' do
      company = build(:company, store: store)
      allow(Spree::Company).to receive(:sole_standing_for).with(store: store, customer: customer).and_return(company)

      expect(described_class.new(store: store, customer: customer).company).to eq(company)
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

    context 'when only a price list prices it in the currency' do
      let(:price_list) { create(:price_list, :active, store: store) }

      before { create(:price, variant: product.default_variant, currency: 'EUR', amount: 10, price_list: price_list) }

      it 'offers it when the list applies to the buyer' do
        expect(context.sellable_variants).to include(product.default_variant)
      end

      it 'skips it when the list is not active' do
        price_list.update!(status: 'draft')

        expect(context.sellable_variants).not_to include(product.default_variant)
      end

      it 'skips it when the list belongs to another buyer' do
        create(:user_price_rule, price_list: price_list, user_ids: [create(:user).id])

        expect(context.sellable_variants).not_to include(product.default_variant)
      end
    end
  end
end
