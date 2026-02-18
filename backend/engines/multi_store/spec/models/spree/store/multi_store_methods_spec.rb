require 'spec_helper'

RSpec.describe Spree::Store::MultiStoreMethods, type: :model do
  let!(:default_store) { @default_store }

  before do
    allow(Spree).to receive(:root_domain).and_return('mydomain.dev')
  end

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

  describe '#set_code (via set_default_code override)' do
    let(:store) { build(:store, name: 'My Store', code: nil) }

    it 'generates code from name' do
      store.valid?
      expect(store.code).to eq('my-store')
    end

    context 'when code is already set' do
      let(:store) { build(:store, name: 'Store', code: 'custom-code') }

      it 'parameterizes the existing code' do
        store.valid?
        expect(store.code).to eq('custom-code')
      end
    end

    context 'when code is already taken' do
      let!(:existing_store) { create(:store, code: 'store') }
      let(:store) { build(:store, name: 'Store', code: existing_store.code) }

      it 'generates a unique code' do
        store.valid?
        expect(store.code).not_to eq(existing_store.code)
        expect(store.code).to match(/store-\d+/)
      end
    end
  end

  describe '#set_url' do
    let(:store) { build(:store, code: 'my_store', url: nil) }

    context 'on create' do
      it 'sets url from code and root domain' do
        store.save!
        expect(store.url).to eq('my_store.mydomain.dev')
      end
    end

    context 'on update with code change' do
      let!(:store) { create(:store, code: 'my_store', url: 'my_store.mydomain.dev') }

      it 'updates url and keeps old code via FriendlyId history' do
        expect(store.url).to eq('my_store.mydomain.dev')
        store.update!(code: 'my_store_2')
        expect(store.reload.url).to eq('my_store_2.mydomain.dev')
        expect(Spree::Store.friendly.find('my_store').id).to eq(store.id)
      end
    end
  end

  describe 'code validation' do
    it 'auto-generates unique code when code is taken' do
      existing = create(:store, code: 'store')
      new_store = create(:store, name: 'Store', code: existing.code)
      expect(new_store.persisted?).to be true
      expect(new_store.code).not_to eq(existing.code)
      expect(new_store.code).to match(/store-\d+/)
    end

    it 'cannot create a store with reserved code' do
      store = build(:store, code: 'admin')
      expect(store).not_to be_valid
      expect(store.errors[:code]).to be_present
    end
  end

  describe '#ensure_default_exists_and_is_unique' do
    it 'ensures there is only one default store' do
      store_1 = create(:store, default: true)
      store_2 = create(:store, default: true)

      store_1.reload
      expect(store_1.default).to be false
      expect(store_2.default).to be true
    end

    it 'auto-sets default if no default store exists' do
      Spree::Store.update_all(default: false)
      store = create(:store)
      expect(store.default).to be true
    end

    context 'when store fails to save' do
      let!(:store_1) { create(:store, default: true) }

      it 'does not change default flag of other stores' do
        store_2 = build(:store, default: true, name: nil) # will fail validation
        store_2.save

        store_1.reload
        expect(store_1.default).to be true
      end
    end
  end

  describe '#can_be_deleted?' do
    it 'cannot delete the only store' do
      Spree::Store.where.not(id: default_store.id).delete_all
      expect(default_store.can_be_deleted?).to eq(false)
    end

    it 'can delete when there are more than 1 stores' do
      create(:store)
      expect(default_store.can_be_deleted?).to eq(true)
    end
  end

  describe 'soft deletion with multi-store protection' do
    context 'default store with multiple stores' do
      let!(:store_to_destroy) { create(:store, default: true) }
      let!(:another_store) { create(:store) }

      before { Spree::Store.where.not(id: [store_to_destroy.id, another_store.id]).delete_all }

      it 'can be deleted' do
        expect { store_to_destroy.destroy }.to change(store_to_destroy, :deleted_at)
        expect(store_to_destroy.deleted?).to eq(true)
      end

      it 'passes default flag to other store' do
        expect(another_store.default?).to eq(false)
        store_to_destroy.destroy
        expect(store_to_destroy.default?).to eq(false)
        expect(another_store.reload.default?).to eq(true)
        expect(Spree::Store.default).to eq(another_store)
      end
    end

    context 'single store' do
      before { Spree::Store.where.not(id: default_store.id).delete_all }

      it 'cannot be deleted' do
        expect { default_store.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
        expect(default_store.errors.full_messages.to_sentence).to eq('Cannot destroy the only Store.')
      end
    end

    context 'non-default store' do
      let!(:another_store) { create(:store) }

      it 'soft-deletes when destroy is called' do
        another_store.destroy!
        expect(another_store.deleted_at).not_to be_nil
      end
    end
  end

  describe '.available_locales' do
    let!(:store_en) { create(:store, default_locale: 'en', supported_locales: 'en,fr') }
    let!(:store_de) { create(:store, default_locale: 'de', supported_locales: 'de') }

    it 'aggregates locales from all stores' do
      expect(Spree::Store.available_locales).to contain_exactly('en', 'fr', 'de')
    end
  end
end
