require 'spec_helper'

describe Spree::BaseHelper, type: :helper do
  include described_class

  let(:current_store) { create(:store) }

  before do
    allow(controller).to receive(:controller_name).and_return('test')
    allow(Rails.application.routes).to receive(:default_url_options).and_return(protocol: 'http', port: nil)
  end

  describe '#spree_storefront_resource_url' do
    let!(:store) { @default_store }
    let!(:category) { create(:category) }
    let!(:product) { create(:product) }

    before do
      allow(helper).to receive(:current_store).and_return(store)
      allow(helper).to receive(:locale_param)
    end

    context 'for Product URL' do
      it { expect(helper.spree_storefront_resource_url(product)).to eq("http://www.example.com/products/#{product.slug}") }

      context 'when a locale is passed' do
        before do
          allow(helper).to receive(:current_store).and_return(store)
        end

        it { expect(helper.spree_storefront_resource_url(product, locale: :de)).to eq("http://www.example.com/de/products/#{product.slug}") }
      end

      context 'when locale_param is present' do
        before do
          allow(helper).to receive(:locale_param).and_return(:fr)
        end

        it { expect(helper.spree_storefront_resource_url(product)).to eq("http://www.example.com/fr/products/#{product.slug}") }
      end

      context 'when preview_id is not present' do
        it 'returns the product url' do
          expect(spree_storefront_resource_url(product)).to eq("http://#{current_store.url}/products/#{product.slug}")
        end
      end

      context 'when preview_id is present' do
        it 'returns the product preview url' do
          expect(spree_storefront_resource_url(product, preview_id: product.id)).to eq("http://#{current_store.url}/products/#{product.slug}?preview_id=#{product.id}")
        end
      end

      context 'for product with relative option' do
        it 'returns the product url' do
          expect(spree_storefront_resource_url(product, relative: true)).to eq("/products/#{product.slug}")
        end
      end
    end

    context 'for Taxon URL' do
      it { expect(helper.spree_storefront_resource_url(category)).to eq("http://www.example.com/t/#{category.permalink}") }

      context 'when a locale is passed' do
        it { expect(helper.spree_storefront_resource_url(category, locale: :de)).to eq("http://www.example.com/de/t/#{category.permalink}") }
      end

      context 'when locale_param is present' do
        before do
          allow(helper).to receive(:locale_param).and_return(:fr)
        end

        it { expect(helper.spree_storefront_resource_url(category)).to eq("http://www.example.com/fr/t/#{category.permalink}") }
      end
    end
  end

end
