require 'spec_helper'

describe Spree::StoreProduct, type: :model do
  let!(:store) { create(:store) }
  let!(:another_store) { create(:store) }
  let!(:product) { create(:product, stores: [store]) }

  context 'assigning store' do
    subject(:assign_store) { product.stores << another_store }

    it 'touches product' do
      expect { assign_store }.to change(product, :updated_at)
    end

    it 'touches store' do
      expect { assign_store }.to change(another_store, :updated_at)
    end

    it 'increases Store Product count' do
      expect { assign_store }.to change(described_class, :count).from(1).to(2)
    end
  end

  context 'unassignes store' do
    subject(:unassign_store) { product.stores.destroy(another_store) }

    before { product.stores << another_store }

    it 'touches product' do
      expect { unassign_store }.to change(product, :updated_at)
    end

    it 'decreases Store Product count' do
      expect { unassign_store }.to change(described_class, :count).from(2).to(1)
    end

    it 'does not remove store' do
      expect { unassign_store }.not_to change { Spree::Store.count }
    end
  end
end
