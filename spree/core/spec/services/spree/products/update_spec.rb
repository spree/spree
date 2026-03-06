require 'spec_helper'

RSpec.describe Spree::Products::Update do
  subject(:result) { described_class.call(product: product, store: store, params: params) }

  let(:store) { @default_store }
  let!(:product) { create(:product, stores: [store]) }

  describe 'basic update' do
    let(:params) { { name: 'Updated Name' } }

    it 'updates the product' do
      expect(result).to be_success
      expect(result.value[:product].name).to eq('Updated Name')
    end
  end

  describe 'validation errors' do
    let(:params) { { name: '' } }

    it 'returns failure' do
      expect(result).not_to be_success
    end
  end

  describe 'tags update' do
    let(:params) { { tags: ['new-tag'] } }

    it 'updates tag_list' do
      expect(result).to be_success
      expect(result.value[:product].tag_list).to eq(['new-tag'])
    end
  end

  describe 'clearing tags' do
    before { product.update!(tag_list: ['old-tag']) }
    let(:params) { { tags: [] } }

    it 'clears all tags' do
      expect(result).to be_success
      expect(result.value[:product].tag_list).to be_empty
    end
  end

  describe 'taxon_ids preserves other store taxons' do
    let(:other_store) { create(:store) }
    let(:taxonomy_this) { create(:taxonomy, store: store) }
    let(:taxonomy_other) { create(:taxonomy, store: other_store) }
    let(:taxon_this) { create(:taxon, taxonomy: taxonomy_this) }
    let(:taxon_other) { create(:taxon, taxonomy: taxonomy_other) }

    before { product.taxons = [taxon_this, taxon_other] }

    let(:new_taxon) { create(:taxon, taxonomy: taxonomy_this) }
    let(:params) { { taxon_ids: [new_taxon.id] } }

    it 'keeps taxons from other stores and replaces current store taxons' do
      expect(result).to be_success
      expect(result.value[:product].taxons).to include(new_taxon, taxon_other)
      expect(result.value[:product].taxons).not_to include(taxon_this)
    end
  end

  describe 'prefixed ID resolution' do
    let(:tax_category) { create(:tax_category) }
    let(:params) { { tax_category_id: tax_category.prefixed_id } }

    it 'resolves prefixed tax_category_id' do
      expect(result).to be_success
      expect(result.value[:product].tax_category).to eq(tax_category)
    end
  end

  describe 'update existing variant by prefixed ID' do
    let!(:variant) { create(:variant, product: product) }
    let(:params) do
      {
        variants: [
          { id: variant.prefixed_id, sku: 'UPDATED-SKU' }
        ]
      }
    end

    it 'updates the variant' do
      expect(result).to be_success
      expect(variant.reload.sku).to eq('UPDATED-SKU')
    end
  end

  describe 'create new variant via update' do
    let(:option_type) { create(:option_type) }

    before { product.option_types << option_type }

    let(:params) do
      {
        variants: [
          { sku: 'NEW-VIA-UPDATE', option_type: option_type.name, option_value: 'XL', price: 20 }
        ]
      }
    end

    it 'creates a new variant' do
      expect { result }.to change { product.variants.count }.by(1)
      expect(result).to be_success
      expect(product.variants.find_by(sku: 'NEW-VIA-UPDATE')).to be_present
    end
  end

  describe 'variant price upsert on update' do
    let!(:variant) { create(:variant, product: product) }
    let(:params) do
      {
        variants: [
          {
            id: variant.prefixed_id,
            prices: [
              { currency: 'GBP', amount: 12.50 }
            ]
          }
        ]
      }
    end

    it 'upserts prices and soft-deletes removed currencies' do
      expect(result).to be_success
      variant.reload
      expect(variant.prices.find_by(currency: 'GBP').amount.to_f).to eq(12.50)
    end
  end

  describe 'nonexistent variant prefixed ID' do
    let(:params) { { variants: [{ id: 'variant_nonexistent', sku: 'X' }] } }

    it 'raises RecordNotFound' do
      expect { result }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'no variants key' do
    let(:params) { { name: 'Just Name' } }

    it 'does not touch variants' do
      expect(result).to be_success
      expect(result.value[:product].name).to eq('Just Name')
    end
  end
end
