require 'spec_helper'

describe Spree::BaseHelper, type: :helper do
  include described_class

  let(:current_store) { create(:store) }

  before do
    allow(controller).to receive(:controller_name).and_return('test')
    allow(Rails.application.routes).to receive(:default_url_options).and_return(protocol: 'http', port: nil)
  end

  context 'available_countries' do
    before do
      create_list(:country, 3)
    end

    context 'with markets' do
      let!(:country) { create(:country) }

      before do
        create(:market, store: current_store, countries: [country], currency: 'USD', default: true)
      end

      it 'returns only the countries from markets' do
        expect(available_countries).to eq([country])
      end
    end

    context 'without markets' do
      it 'returns complete list of countries' do
        expect(available_countries).to contain_exactly(*Spree::Country.all)
      end
    end
  end

  describe '#spree_storefront_resource_url' do
    let!(:store) { @default_store }
    let!(:taxon) { create(:taxon) }
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
      it { expect(helper.spree_storefront_resource_url(taxon)).to eq("http://www.example.com/t/#{taxon.permalink}") }

      context 'when a locale is passed' do
        it { expect(helper.spree_storefront_resource_url(taxon, locale: :de)).to eq("http://www.example.com/de/t/#{taxon.permalink}") }
      end

      context 'when locale_param is present' do
        before do
          allow(helper).to receive(:locale_param).and_return(:fr)
        end

        it { expect(helper.spree_storefront_resource_url(taxon)).to eq("http://www.example.com/fr/t/#{taxon.permalink}") }
      end
    end
  end

  context 'spree_base_cache_key' do
    let(:current_currency) { 'USD' }

    context 'when try_spree_current_user defined' do
      before do
        allow(I18n).to receive(:locale).and_return(I18n.default_locale)
        allow_any_instance_of(described_class).to receive(:try_spree_current_user).and_return(user)
      end

      context 'when admin user' do
        let!(:user) { create(:admin_user) }

        it 'returns base cache key' do
          expect(spree_base_cache_key).to eq [:en, 'USD', true, user.role_users.cache_key_with_version]
        end
      end

      context 'when user without admin role' do
        let!(:user) { create(:user) }

        it 'returns base cache key' do
          expect(spree_base_cache_key).to eq [:en, 'USD', true, user.role_users.cache_key_with_version]
        end
      end

      context 'when spree_current_user is nil' do
        let!(:user) { nil }

        it 'returns base cache key' do
          expect(spree_base_cache_key).to eq [:en, 'USD', false, false]
        end
      end
    end

    context 'when try_spree_current_user is undefined' do
      let(:current_currency) { 'USD' }

      before do
        allow(I18n).to receive(:locale).and_return(I18n.default_locale)
      end

      it 'returns base cache key' do
        expect(spree_base_cache_key).to eq [:en, 'USD']
      end
    end
  end
end
