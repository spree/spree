require 'spec_helper'

describe Spree::StorePreferences do
  let(:store) { @default_store }

  describe '.read' do
    it "returns the store's value" do
      stub_store_preferences(store, track_inventory_levels: false)

      expect(described_class.read(store, :track_inventory_levels)).to be(false)
    end

    # A console session, a seed, or a job that never set the ambient store must
    # not blow up — it falls back to what the preference declares.
    it 'falls back to the declared default without a store' do
      expect(described_class.read(nil, :track_inventory_levels)).to be(true)
      expect(described_class.read(nil, :show_products_without_price)).to be(false)
    end
  end

  describe '.current' do
    it 'reads through the ambient store' do
      stub_store_preferences(store, show_products_without_price: true)

      expect(described_class.current(:show_products_without_price)).to be(true)
    end
  end

  describe '#store_preference' do
    it 'reads through the store the record belongs to' do
      payment_method = create(:payment_method, store: store)
      stub_store_preferences(store, capture_method: 'on_dispatch')

      expect(payment_method.store_preference(:capture_method)).to eq('on_dispatch')
    end

    it 'follows an overridden preference_store' do
      other_store = create(:store)
      product = create(:product, store: other_store)
      stub_store_preferences(other_store, track_inventory_levels: false)

      expect(product.variants.first.store_preference(:track_inventory_levels)).to be(false)
    end

    it 'falls back to the declared default when the record has no store' do
      expect(Spree::Product.new.store_preference(:track_inventory_levels)).to be(true)
    end
  end
end
