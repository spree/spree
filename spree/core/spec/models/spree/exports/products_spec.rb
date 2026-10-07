require 'spec_helper'

RSpec.describe Spree::Exports::Products, type: :model do
  let(:store) { @default_store }
  let(:export) { described_class.new(store: store) }

  describe '#scope' do
    let!(:archived_product) { create(:product, status: 'archived') }
    let!(:test_product) { create(:product, name: 'test') }

    context 'when search_params is nil' do
      it 'excludes archived products' do
        expect(export.scope).to include(test_product)
        expect(export.scope).not_to include(archived_product)
      end
    end

    context 'when search_params is present' do
      let(:export) { described_class.new(store: store, search_params: { name: 'test' }) }

      it 'includes all products' do
        expect(export.scope).to include(test_product)
        expect(export.scope).to include(archived_product)
      end
    end
  end

  describe '#generate' do
    let(:seller) { create(:seller, :approved, store: store) }
    let(:product) { create(:product, store: store, seller: seller) }
    let(:seller_location) { create(:stock_location, store: store, seller: seller, name: 'Seller Shed') }

    before do
      product.default_variant.update!(sku: 'SHED-MUG', track_inventory: true)
      product.default_variant.set_stock(12, false, store.default_stock_location)
      product.default_variant.set_stock(7, false, seller_location)
    end

    it "writes only a seller's own stock on the seller's export" do
      export = described_class.new(store: store, seller: seller)
      export.save!
      export.generate

      rows = CSV.parse(export.attachment.download, headers: true)
      expect(rows.map { |row| row.values_at('sku', 'inventory_count', 'stock_location') }).to eq [['SHED-MUG', '7', nil]]
    end
  end

  describe '#csv_headers' do
    context 'when no custom_fields' do
      it 'returns product variant headers without properties' do
        expected_headers = [
          'product_id',
          'sku',
          'name',
          'slug',
          'status',
          'seller_name',
          'description',
          'meta_title',
          'meta_description',
          'meta_keywords',
          'tags',
          'labels',
          'price',
          'compare_at_price',
          'currency',
          'width',
          'height',
          'depth',
          'dimensions_unit',
          'weight',
          'weight_unit',
          'available_on',
          'discontinue_on',
          'track_inventory',
          'inventory_count',
          'inventory_backorderable',
          'stock_location',
          'tax_category',
          'product_type',
          'image1_src',
          'image2_src',
          'image3_src',
          'option1_name',
          'option1_value',
          'option2_name',
          'option2_value',
          'option3_name',
          'option3_value',
          'category1',
          'category2',
          'category3'
        ]
        expect(export.csv_headers).to eq(expected_headers)
      end
    end

    context 'when custom_fields exist' do
      let!(:custom_field_definition) { create(:custom_field_definition, resource_type: 'Spree::Product', namespace: 'custom', key: 'field1') }

      it 'includes custom_field headers' do
        expected_headers = [
          'product_id',
          'sku',
          'name',
          'slug',
          'status',
          'seller_name',
          'description',
          'meta_title',
          'meta_description',
          'meta_keywords',
          'tags',
          'labels',
          'price',
          'compare_at_price',
          'currency',
          'width',
          'height',
          'depth',
          'dimensions_unit',
          'weight',
          'weight_unit',
          'available_on',
          'discontinue_on',
          'track_inventory',
          'inventory_count',
          'inventory_backorderable',
          'stock_location',
          'tax_category',
          'product_type',
          'image1_src',
          'image2_src',
          'image3_src',
          'option1_name',
          'option1_value',
          'option2_name',
          'option2_value',
          'option3_name',
          'option3_value',
          'category1',
          'category2',
          'category3',
          'custom_field.custom.field1'
        ]
        expect(export.csv_headers).to eq(expected_headers)
      end
    end
  end
end
