require 'spec_helper'

module Spree
  RSpec.describe SearchProvider::ProductPresenter do
    let(:store) { @default_store }
    let(:product) { create(:product, name: 'Test Shirt', stores: [store]) }
    let(:presenter) { described_class.new(product, store) }

    describe '#call' do
      subject(:documents) { presenter.call }

      it 'returns an array of documents' do
        expect(documents).to be_an(Array)
        expect(documents).not_to be_empty
      end

      context 'document structure' do
        subject(:doc) { documents.first }

        it 'includes composite prefixed_id and product_id' do
          expect(doc[:prefixed_id]).to start_with(product.prefixed_id)
          expect(doc[:product_id]).to eq(product.prefixed_id)
        end

        it 'includes locale and currency' do
          expect(doc[:locale]).to be_present
          expect(doc[:currency]).to be_present
        end

        it 'includes flat name and description' do
          expect(doc[:name]).to eq('Test Shirt')
          expect(doc[:slug]).to eq(product.slug)
        end

        it 'includes flat price' do
          expect(doc).to have_key(:price)
        end

        it 'includes stock status' do
          expect(doc).to have_key(:in_stock)
        end

        it 'includes timestamps' do
          expect(doc[:created_at]).to be_present
          expect(doc[:updated_at]).to be_present
        end

        it 'includes category data as prefixed IDs' do
          expect(doc[:category_ids]).to be_an(Array)
        end

        it 'includes option data as prefixed IDs' do
          expect(doc[:option_type_ids]).to be_an(Array)
          expect(doc[:option_value_ids]).to be_an(Array)
        end
      end

      context 'with categories' do
        let(:taxonomy) { create(:taxonomy, store: store) }
        let(:taxon) { create(:taxon, taxonomy: taxonomy) }
        let(:product) { create(:product, name: 'Test Shirt', stores: [store], taxons: [taxon]) }

        it 'indexes category_ids as prefixed IDs including ancestors' do
          doc = documents.first
          expect(doc[:category_ids]).to include(taxon.prefixed_id)
          expect(doc[:category_ids]).to include(taxonomy.root.prefixed_id)
          doc[:category_ids].each { |id| expect(id).to start_with('ctg_') }
        end
      end

      context 'with nested categories' do
        let(:taxonomy) { create(:taxonomy, store: store) }
        let(:parent) { create(:taxon, taxonomy: taxonomy, name: 'Men') }
        let(:child) { create(:taxon, taxonomy: taxonomy, parent: parent, name: 'Jackets') }
        let(:product) { create(:product, name: 'Test Jacket', stores: [store], taxons: [child]) }

        it 'indexes all ancestor category IDs so parent-level filtering works' do
          doc = documents.first
          expect(doc[:category_ids]).to include(child.prefixed_id)
          expect(doc[:category_ids]).to include(parent.prefixed_id)
          expect(doc[:category_ids]).to include(taxonomy.root.prefixed_id)
        end
      end

      context 'with multiple markets' do
        let!(:us_market) { create(:market, store: store, name: 'US', currency: 'USD', default_locale: 'en') }
        let!(:eu_market) { create(:market, store: store, name: 'EU', currency: 'EUR', default_locale: 'de', supported_locales: 'de,fr') }

        # Product with prices in both currencies
        let(:product) do
          p = create(:product, name: 'Test Shirt', stores: [store])
          create(:price, variant: p.master, amount: 29.99, currency: 'EUR')
          p
        end

        # Reload store to pick up new markets
        let(:presenter) { described_class.new(product, store.reload) }

        it 'creates one document per market × locale where product has a price' do
          locales_currencies = documents.map { |d| [d[:locale], d[:currency]] }
          expect(locales_currencies).to include(['en', 'USD'])
          expect(locales_currencies).to include(['de', 'EUR'])
          expect(locales_currencies).to include(['fr', 'EUR'])
          expect(documents.size).to eq(3)
        end

        it 'each document has the correct currency and locale' do
          usd_doc = documents.find { |d| d[:currency] == 'USD' }
          eur_doc = documents.find { |d| d[:currency] == 'EUR' && d[:locale] == 'de' }

          expect(usd_doc[:locale]).to eq('en')
          expect(eur_doc[:locale]).to eq('de')
        end

        it 'each document has a unique composite prefixed_id' do
          ids = documents.map { |d| d[:prefixed_id] }
          expect(ids.uniq.size).to eq(ids.size)
        end

        it 'composite prefixed_id includes product_id, locale, and currency' do
          doc = documents.first
          expect(doc[:prefixed_id]).to match(/\A#{product.prefixed_id}_\w+_[A-Z]{3}\z/)
        end

        it 'includes the price for each currency' do
          usd_doc = documents.find { |d| d[:currency] == 'USD' }
          eur_doc = documents.find { |d| d[:currency] == 'EUR' }

          expect(usd_doc[:price]).to be_present
          expect(eur_doc[:price]).to eq(29.99)
        end

        it 'all documents share the same product_id' do
          product_ids = documents.map { |d| d[:product_id] }.uniq
          expect(product_ids).to eq([product.prefixed_id])
        end
      end

      context 'with market but product has no price in that currency' do
        let!(:us_market) { create(:market, store: store, name: 'US', currency: 'USD', default_locale: 'en') }
        let!(:eu_market) { create(:market, store: store, name: 'EU', currency: 'EUR', default_locale: 'de') }

        # Product with USD price only — no EUR price
        let(:product) { create(:product, name: 'USD Only Product', stores: [store]) }
        let(:presenter) { described_class.new(product, store.reload) }

        it 'skips markets where product has no price' do
          currencies = documents.map { |d| d[:currency] }
          expect(currencies).to include('USD')
          expect(currencies).not_to include('EUR')
        end

        it 'only creates documents for markets with matching prices' do
          expect(documents.size).to eq(1)
          expect(documents.first[:currency]).to eq('USD')
        end
      end

      context 'translation fallback' do
        let!(:us_market) { create(:market, store: store, name: 'US', currency: 'USD', default_locale: 'en') }
        let!(:eu_market) { create(:market, store: store, name: 'EU', currency: 'EUR', default_locale: 'de') }

        let(:product) do
          p = create(:product, name: 'English Name', stores: [store])
          create(:price, variant: p.master, amount: 19.99, currency: 'EUR')
          p
        end

        let(:presenter) { described_class.new(product, store.reload) }

        it 'falls back to default locale name when translation is missing' do
          de_doc = documents.find { |d| d[:locale] == 'de' }
          expect(de_doc[:name]).to eq('English Name')
        end
      end

      context 'with option values' do
        let(:product) { create(:product_with_option_types, stores: [store]) }

        it 'includes option value prefixed IDs' do
          doc = documents.first
          doc[:option_value_ids].each do |ov_id|
            expect(ov_id).to start_with('optval_')
          end
        end
      end
    end
  end
end
