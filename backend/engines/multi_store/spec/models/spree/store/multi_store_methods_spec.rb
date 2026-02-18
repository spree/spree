require 'spec_helper'

RSpec.describe Spree::Store::MultiStoreMethods, type: :model do
  let!(:default_store) { @default_store }

  describe 'URL-based store resolution' do
    # Use a URL that won't substring-match via LIKE with other test URLs
    let!(:store_2) { create(:store, url: 'mystore.test') }

    before { Spree::Current.store = nil }

    describe '.by_url' do
      it 'finds stores matching URL' do
        expect(Spree::Store.by_url('mystore.test')).to include(store_2)
      end

      it 'finds stores matching partial URL via LIKE' do
        expect(Spree::Store.by_url('mystore.test')).to include(store_2)
      end

      it 'does not return non-matching stores' do
        expect(Spree::Store.by_url('nomatch.xyz')).not_to include(store_2)
      end
    end

    describe '.by_custom_domain' do
      let!(:custom_domain) { create(:custom_domain, store: store_2, url: 'myshop.com') }

      it 'finds store by custom domain' do
        expect(Spree::Store.by_custom_domain('myshop.com')).to include(store_2)
      end

      it 'does not return non-matching stores' do
        expect(Spree::Store.by_custom_domain('nomatch.xyz')).not_to include(store_2)
      end
    end

    describe '.current' do
      it 'resolves store by URL via finder' do
        expect(Spree::Store.current('mystore.test')).to eq(store_2)
      end

      it 'falls back to default store for unknown URL' do
        expect(Spree::Store.current('unknown.com')).to eq(default_store)
      end

      it 'sets Spree::Current.store' do
        Spree::Store.current('mystore.test')
        expect(Spree::Current.store).to eq(store_2)
      end

      context 'with custom domain' do
        let!(:custom_domain) { create(:custom_domain, store: store_2, url: 'myshop.com') }

        it 'resolves store by custom domain' do
          expect(Spree::Store.current('myshop.com')).to eq(store_2)
        end
      end
    end
  end

  describe 'custom domain associations' do
    let(:store) { create(:store) }

    it 'has_many custom_domains' do
      domain = create(:custom_domain, store: store)
      expect(store.custom_domains).to include(domain)
    end

    it 'returns default_custom_domain' do
      # First domain created becomes default via ensure_default callback
      first_domain = create(:custom_domain, store: store, url: 'first.com')
      expect(first_domain.reload.default).to be true

      # Second domain is not default
      second_domain = create(:custom_domain, store: store, url: 'second.com')
      expect(second_domain.reload.default).to be false

      expect(store.reload.default_custom_domain).to eq(first_domain)
    end

    it 'destroys custom domains when store is destroyed' do
      create(:custom_domain, store: store)
      expect { store.destroy }.to change(Spree::CustomDomain, :count).by(-1)
    end
  end

  describe '#url_or_custom_domain' do
    let(:store) { create(:store, url: 'store.mysite.com') }

    context 'without custom domain' do
      it 'returns the store url' do
        expect(store.url_or_custom_domain).to eq('store.mysite.com')
      end
    end

    context 'with custom domain' do
      let!(:domain) { create(:custom_domain, store: store, url: 'custom.shop.com') }

      it 'returns the custom domain url' do
        # First custom domain becomes default via ensure_default callback
        expect(domain.reload.default).to be true
        expect(store.reload.url_or_custom_domain).to eq('custom.shop.com')
      end
    end
  end

  describe 'product import on create' do
    let!(:product) { create(:product, stores: [default_store]) }

    it 'imports products from source store' do
      new_store = build(:store, import_products_from_store_id: default_store.id)
      new_store.save!

      expect(new_store.products).to include(product)
    end

    it 'does not import products when source store is not set' do
      new_store = create(:store)
      expect(new_store.products).to be_empty
    end
  end

  describe 'payment method import on create' do
    let!(:payment_method) { create(:credit_card_payment_method, stores: [default_store]) }

    it 'imports payment methods from source store' do
      new_store = build(:store, import_payment_methods_from_store_id: default_store.id)
      new_store.save!

      expect(new_store.payment_methods).to include(payment_method)
    end
  end
end
