require 'spec_helper'

RSpec.describe Spree::RansackableAttributes do
  describe 'for the back office' do
    it 'allows every allowlisted association and attribute' do
      expect(Spree::Order.ransackable_associations).to include('customer', 'promotions')
      expect(Spree::Order.ransackable_attributes).to include('email')
      expect(Spree::Variant.ransackable_attributes).to include('cost_price')
    end
  end

  describe 'for the Store API' do
    it 'reaches only the associations a storefront filters by' do
      expect(Spree::Product.ransackable_associations(:store)).to match_array(%w[tags categories collections])
      expect(Spree::Order.ransackable_associations(:store)).to be_empty
    end

    it 'drops private attributes' do
      expect(Spree::Order.ransackable_attributes(:store)).not_to include('email', 'considered_risky')
      expect(Spree::Order.ransackable_attributes(:store)).to include('number')
      expect(Spree::Variant.ransackable_attributes(:store)).not_to include('cost_price')
      expect(Spree::StoreCredit.ransackable_attributes(:store)).not_to include('memo')
    end
  end

  describe 'for the Seller API' do
    it 'reaches no associations' do
      expect(Spree::Order.ransackable_associations(:seller)).to be_empty
      expect(Spree::Product.ransackable_associations(:seller)).to be_empty
    end

    it "drops the buyer's email and the searches that match on it" do
      expect(Spree::Order.ransackable_attributes(:seller)).not_to include('email')
      expect(Spree::Order.ransackable_scopes(:seller)).not_to include('search')
    end
  end

  describe '.search_by' do
    let(:store) { @default_store }

    it 'matches any declared attribute, partially and case-insensitively' do
      supplier = create(:supplier, store: store, name: 'Acme Supplies', contact_name: 'Jane Roe', email: 'orders@acme.test')
      other = create(:supplier, store: store, name: 'Globex', contact_name: 'John Doe', email: 'hello@globex.test')

      expect(Spree::Supplier.search('acme')).to contain_exactly(supplier)
      expect(Spree::Supplier.search('JANE')).to contain_exactly(supplier)
      expect(Spree::Supplier.search('')).to include(supplier, other)
    end

    it 'reaches through associations' do
      variant = create(:variant, sku: 'SEARCH-SKU-1')

      expect(Spree::StockLevel.search('search-sku')).to include(*variant.stock_levels)
    end

    it 'is offered to an audience only when it may filter on every searched attribute' do
      expect(Spree::StoreCredit.ransackable_scopes).to include('search')
      expect(Spree::StoreCredit.ransackable_scopes(:store)).not_to include('search')
      expect(Spree::StockLevel.ransackable_scopes(:store)).not_to include('search')
      expect(Spree::Collection.ransackable_scopes(:store)).to include('search')
    end
  end
end
