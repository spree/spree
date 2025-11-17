require 'spec_helper'

RSpec.describe Spree::Exports::Products, type: :model do
  let(:store) { create(:store) }
  let(:export) { described_class.new(store: store) }

  describe '#scope' do
    let!(:archived_product) { create(:product, status: 'archived', stores: [store]) }
    let!(:test_product) { create(:product, name: 'test', stores: [store]) }

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

  describe '#csv_headers' do
    context 'when product_properties_enabled is false and no metafields' do
      before do
        allow(Spree::Config).to receive(:[]).with(:product_properties_enabled).and_return(false)
      end

      it 'returns product variant headers without properties' do
        expected_headers = [
          'product_id',
          'sku',
          'name',
          'slug',
          'status',
          'vendor_name',
          'brand_name',
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
          'tax_category',
          'shipping_category',
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

    context 'when product_properties_enabled is true' do
      before do
        allow(Spree::Config).to receive(:[]).with(:product_properties_enabled).and_return(true)
        create(:property)
      end

      it 'includes property headers' do
        expected_headers = [
          'product_id',
          'sku',
          'name',
          'slug',
          'status',
          'vendor_name',
          'brand_name',
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
          'tax_category',
          'shipping_category',
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
          'property1_name',
          'property1_value'
        ]
        expect(export.csv_headers).to eq(expected_headers)
      end
    end

    context 'when metafields exist' do
      before do
        allow(Spree::Config).to receive(:[]).with(:product_properties_enabled).and_return(false)
      end

      let!(:metafield_definition) { create(:metafield_definition, resource_type: 'Spree::Product', namespace: 'custom', key: 'field1') }

      it 'includes metafield headers' do
        expected_headers = [
          'product_id',
          'sku',
          'name',
          'slug',
          'status',
          'vendor_name',
          'brand_name',
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
          'tax_category',
          'shipping_category',
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
          'metafield.custom.field1'
        ]
        expect(export.csv_headers).to eq(expected_headers)
      end
    end
  end
end
