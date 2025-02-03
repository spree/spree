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
    before do
      allow(export).to receive_messages(max_taxons_count: 3, properties_headers: ['property1_name', 'property1_value'])
    end

    it 'includes product variant headers plus taxon and property headers' do
      expect(export.csv_headers).to eq(
        Spree::CSV::ProductVariantPresenter::CSV_HEADERS + ['category1', 'category2', 'category3'] +
        ['property1_name', 'property1_value']
      )
    end
  end

  describe '#max_taxons_count' do
    let(:other_store) { create(:store) }
    let(:taxonomy) { create(:taxonomy, store: store) }
    let(:taxons) { create_list(:taxon, 6, store: store, automatic: false, taxonomy: taxonomy) }
    let(:automatic_taxon) { create(:taxon, store: store, automatic: true, taxonomy: taxonomy) }
    let(:product) { create(:product, stores: [store]) }
    let(:second_product) { create(:product, stores: [store]) }
    let(:product_from_another_store) { create(:product, stores: [other_store]) }
    let(:other_taxon) { create(:taxon, store: other_store, automatic: false) }

    before do
      4.times.each do |i|
        product.taxons << taxons[i]
      end
      (4...6).each do |i|
        second_product.taxons << taxons[i]
      end

      product.taxons << automatic_taxon

      product_from_another_store.taxons << other_taxon
    end

    it 'returns maximum of taxon count of a single product in the store' do
      expect(export.max_taxons_count).to eq 4
    end
  end
end
