require 'spec_helper'

describe Spree::StoreProduct, type: :model do
  let!(:store)    { create(:store) }
  let!(:store_2)  { create(:store) }
  let!(:product)  { create(:product) }

  context 'assigning store' do
    it 'touches product' do
      expect { product.stores << store }.to change { product.reload.updated_at }
    end

    it 'increases Store Product count' do
      expect { product.stores << store }.to change(described_class, :count).from(0).to(1)
    end
  end

  context 'unassignes store' do
    before { product.stores << store }

    it 'touches product' do
      expect { product.stores.destroy(store) }.to change { product.reload.updated_at }
    end

    it 'decreases Store Product count' do
      expect { product.stores.destroy(store) }.to change(described_class, :count).from(1).to(0)
    end

    it 'does not remove store' do
      expect { product.stores.destroy(store) }.not_to change { Spree::Store.count }
    end
  end
end
