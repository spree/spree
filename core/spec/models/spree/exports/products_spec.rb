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
    subject { export.csv_headers }

    let(:categories_taxonomy) { store.taxonomies.find_by(name: Spree.t(:taxonomy_categories_name)) }
    let!(:taxons) { create_list(:taxon, 6, taxonomy: categories_taxonomy) }

    let!(:properties) { create_list(:property, 2) }

    let!(:product_1) { create(:product, stores: [store], taxons: taxons[0...3]) }
    let!(:variant_1_1) { create(:variant, product: product_1, option_values: [red_color, small_size, cotton_material, regular_type]) }
    let!(:images_1) { create_list(:image, 5, viewable: variant_1_1) }

    let!(:product_2) { create(:product, stores: [store], taxons: taxons) }
    let!(:variant_2_1) { create(:variant, product: product_2, option_values: [green_color, medium_size, leather_material, slim_type]) }
    let!(:images_2) { create_list(:image, 2, viewable: variant_2_1) }

    let(:color_option) { create(:option_type, name: 'color', presentation: 'Color', products: [product_1, product_2]) }
    let(:red_color) { create(:option_value, name: 'red', presentation: 'Red', option_type: color_option) }
    let(:green_color) { create(:option_value, name: 'green', presentation: 'Green', option_type: color_option) }

    let(:size_option) { create(:option_type, name: 'size', presentation: 'Size', products: [product_1, product_2]) }
    let(:small_size) { create(:option_value, name: 'small', presentation: 'Small', option_type: size_option) }
    let(:medium_size) { create(:option_value, name: 'medium', presentation: 'Medium', option_type: size_option) }

    let(:material_option) { create(:option_type, name: 'material', presentation: 'Material', products: [product_1, product_2]) }
    let(:cotton_material) { create(:option_value, name: 'cotton', presentation: 'Cotton', option_type: material_option) }
    let(:leather_material) { create(:option_value, name: 'leather', presentation: 'Leather', option_type: material_option) }

    let(:type_option) { create(:option_type, name: 'type', presentation: 'Type', products: [product_1, product_2]) }
    let(:regular_type) { create(:option_value, name: 'regular', presentation: 'Regular', option_type: type_option) }
    let(:slim_type) { create(:option_value, name: 'slim', presentation: 'Slim', option_type: type_option) }

    let(:all_headers) do
      [
        *Spree::CSV::ProductVariantPresenter::CSV_HEADERS,
        'image1_src',
        'image2_src',
        'image3_src',
        'image4_src',
        'image5_src',
        'option1_name',
        'option1_value',
        'option2_name',
        'option2_value',
        'option3_name',
        'option3_value',
        'option4_name',
        'option4_value',
        'category1',
        'category2',
        'category3',
        'category4',
        'category5',
        'category6',
        'property1_name',
        'property1_value',
        'property2_name',
        'property2_value'
      ]
    end

    it { is_expected.to eq(all_headers) }
  end
end
