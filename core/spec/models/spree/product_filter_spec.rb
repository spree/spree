require 'spec_helper'
require 'spree/core/product_filters'

describe 'product filters', type: :model do
  let(:store) { create(:store) }

  # Regression test for #1709
  context 'finds products filtered by brand' do
    let(:product) { create(:product, stores: [store]) }

    before do
      Spree::Property.create!(name: 'brand', presentation: 'brand')
      product.set_property('brand', 'Nike')
    end

    it 'does not attempt to call value method on Arel::Table' do
      expect { Spree::Core::ProductFilters.brand_filter }.not_to raise_error
    end

    it "can find products in the 'Nike' brand" do
      expect(Spree::Product.brand_any('Nike')).to include(product)
    end
  end
end
