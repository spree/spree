require 'spec_helper'

RSpec.describe Spree::Products::Create do
  subject(:result) { described_class.call(store: store, params: params) }

  let(:store) { @default_store }
  let(:shipping_category) { create(:shipping_category) }

  describe 'basic product creation' do
    let(:params) { { name: 'Test Product', price: 19.99, shipping_category_id: shipping_category.id } }

    it 'creates a product' do
      expect(result).to be_success
      expect(result.value[:product].name).to eq('Test Product')
      expect(result.value[:product].stores).to include(store)
    end
  end

  describe 'validation errors' do
    let(:params) { { name: '' } }

    it 'returns failure with errors' do
      expect(result).not_to be_success
      expect(result.error).to be_present
    end
  end

  describe 'tags mapping' do
    let(:params) { { name: 'Tagged Product', price: 10, shipping_category_id: shipping_category.id, tags: ['eco', 'sale'] } }

    it 'maps tags to tag_list' do
      expect(result).to be_success
      expect(result.value[:product].tag_list).to match_array(['eco', 'sale'])
    end
  end

  describe 'prefixed ID resolution' do
    let(:tax_category) { create(:tax_category) }
    let(:taxonomy) { create(:taxonomy, store: store) }
    let(:taxon) { create(:taxon, taxonomy: taxonomy) }

    let(:params) do
      {
        name: 'Resolved Product',
        price: 10,
        shipping_category_id: shipping_category.prefixed_id,
        tax_category_id: tax_category.prefixed_id,
        taxon_ids: [taxon.prefixed_id]
      }
    end

    it 'resolves prefixed IDs for associations' do
      expect(result).to be_success
      product = result.value[:product]
      expect(product.shipping_category).to eq(shipping_category)
      expect(product.tax_category).to eq(tax_category)
      expect(product.taxons).to include(taxon)
    end
  end

  describe 'invalid prefixed ID' do
    let(:params) { { name: 'Bad ID', price: 10, shipping_category_id: shipping_category.id, tax_category_id: 'tc_nonexistent' } }

    it 'raises RecordNotFound' do
      expect { result }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'nested variants' do
    let(:params) do
      {
        name: 'Product With Variants',
        price: 10,
        shipping_category_id: shipping_category.id,
        variants: [
          { sku: 'VAR-1', option_type: 'Size', option_value: 'Small', price: 10 },
          { sku: 'VAR-2', option_type: 'Size', option_value: 'Large', price: 15 }
        ]
      }
    end

    it 'creates variants with option types auto-created' do
      expect(result).to be_success
      product = result.value[:product]
      expect(product.variants.count).to eq(2)
      expect(product.variants.pluck(:sku)).to match_array(%w[VAR-1 VAR-2])
      expect(product.option_types.map(&:name)).to include('size')
    end
  end

  describe 'variant with prices upserted' do
    let(:params) do
      {
        name: 'Multi-price Product',
        price: 10,
        shipping_category_id: shipping_category.id,
        variants: [
          {
            sku: 'MP-1',
            option_type: 'Color',
            option_value: 'Red',
            prices: [
              { currency: 'USD', amount: 10.99, compare_at_amount: 14.99 },
              { currency: 'EUR', amount: 9.50 }
            ]
          }
        ]
      }
    end

    it 'upserts prices for the variant' do
      expect(result).to be_success
      variant = result.value[:product].variants.find_by(sku: 'MP-1')
      usd = variant.prices.find_by(currency: 'USD')
      eur = variant.prices.find_by(currency: 'EUR')

      expect(usd.amount.to_f).to eq(10.99)
      expect(usd.compare_at_amount.to_f).to eq(14.99)
      expect(eur.amount.to_f).to eq(9.50)
    end
  end

  describe 'variant with total_on_hand' do
    let!(:stock_location) { create(:stock_location, propagate_all_variants: true) }

    let(:params) do
      {
        name: 'Stocked Product',
        price: 10,
        shipping_category_id: shipping_category.id,
        variants: [
          { sku: 'STK-1', option_type: 'Size', option_value: 'M', total_on_hand: 25 }
        ]
      }
    end

    it 'sets stock level' do
      expect(result).to be_success
      variant = result.value[:product].variants.find_by(sku: 'STK-1')
      expect(variant.total_on_hand).to eq(25)
    end
  end

  describe 'empty variants array' do
    let(:params) { { name: 'No Variants', price: 5, shipping_category_id: shipping_category.id, variants: [] } }

    it 'creates product without extra variants' do
      expect(result).to be_success
      expect(result.value[:product].variants.count).to eq(0)
    end
  end

  describe 'without store_ids assigns current store' do
    let(:params) { { name: 'Auto Store', price: 5, shipping_category_id: shipping_category.id } }

    it 'assigns the provided store' do
      expect(result).to be_success
      expect(result.value[:product].stores).to eq([store])
    end
  end
end
