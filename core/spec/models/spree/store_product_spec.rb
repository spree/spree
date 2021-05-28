require 'spec_helper'

describe Spree::StoreProduct, type: :model do
  let!(:store) { create(:store) }
  let!(:product) { create(:product, with_store: false) }

  context 'assigning store' do
    subject(:assign_store) { product.stores << store }

    it 'touches product' do
      expect { assign_store }.to change(product, :updated_at)
    end

    it 'touches store' do
      expect { assign_store }.to change(store, :updated_at)
    end

    it 'increases Store Product count' do
      expect { assign_store }.to change(described_class, :count).from(0).to(1)
    end
  end

  context 'unassignes store' do
    subject(:unassign_store) { product.stores.destroy(store) }

    before { product.stores << store }

    it 'touches product' do
      expect { unassign_store }.to change(product, :updated_at)
    end

    it 'decreases Store Product count' do
      expect { unassign_store }.to change(described_class, :count).from(1).to(0)
    end

    it 'does not remove store' do
      expect { unassign_store }.not_to change { Spree::Store.count }
    end
  end
end
