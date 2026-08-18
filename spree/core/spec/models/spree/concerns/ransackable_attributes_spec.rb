require 'spec_helper'

RSpec.describe Spree::RansackableAttributes do
  before do
    Spree.ransack.reset!
  end

  after do
    Spree.ransack.reset!
  end

  describe '.ransackable_attributes' do
    it 'returns default and whitelisted attributes' do
      expect(Spree::Product.ransackable_attributes).to include('id', 'name', 'description', 'slug')
    end

    it 'merges custom attributes from Spree.ransack' do
      Spree.ransack.add_attribute(Spree::Product, :seller_id)

      expect(Spree::Product.ransackable_attributes).to include('seller_id')
    end

    it 'does not duplicate attributes' do
      Spree.ransack.add_attribute(Spree::Product, :name)

      expect(Spree::Product.ransackable_attributes.count('name')).to eq(1)
    end
  end

  describe '.ransackable_associations' do
    it 'returns whitelisted associations' do
      expect(Spree::Product.ransackable_associations).to include('categories', 'variants')
    end

    it 'merges custom associations from Spree.ransack' do
      Spree.ransack.add_association(Spree::Product, :seller)

      expect(Spree::Product.ransackable_associations).to include('seller')
    end

    it 'does not duplicate associations' do
      Spree.ransack.add_association(Spree::Product, :taxons)

      expect(Spree::Product.ransackable_associations.count('taxons')).to eq(1)
    end
  end

  describe '.ransackable_scopes' do
    it 'returns whitelisted scopes' do
      expect(Spree::Product.ransackable_scopes).to include('not_discontinued', 'search_by_name')
    end

    it 'merges custom scopes from Spree.ransack' do
      Spree.ransack.add_scope(Spree::Product, :by_seller)

      expect(Spree::Product.ransackable_scopes).to include('by_seller')
    end

    it 'does not duplicate scopes' do
      Spree.ransack.add_scope(Spree::Product, :not_discontinued)

      expect(Spree::Product.ransackable_scopes.count('not_discontinued')).to eq(1)
    end
  end
end
