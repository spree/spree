require 'spec_helper'

RSpec.describe Spree::Variants::Create do
  subject(:result) { described_class.call(product: product, params: params) }

  let(:store) { @default_store }
  let!(:product) { create(:product, stores: [store]) }
  let(:option_type) { create(:option_type) }
  let(:option_value) { create(:option_value, option_type: option_type) }

  before { product.option_types << option_type }

  describe 'basic variant creation' do
    let(:params) { { sku: 'NEW-V1', price: 10, option_type: option_type.name, option_value: option_value.name } }

    it 'creates a variant' do
      expect(result).to be_success
      expect(result.value[:variant].sku).to eq('NEW-V1')
      expect(result.value[:variant].product).to eq(product)
    end
  end

  describe 'validation error - missing option values' do
    let(:params) { { sku: 'NO-OPT' } }

    it 'returns failure' do
      expect(result).not_to be_success
    end
  end

  describe 'validation error - duplicate sku' do
    let!(:existing) { create(:variant, product: product, sku: 'DUPE') }
    let(:params) { { sku: 'DUPE', option_type: option_type.name, option_value: 'unique-val' } }

    it 'returns failure with sku error' do
      expect(result).not_to be_success
    end
  end

  describe 'with nested prices' do
    let(:params) do
      {
        sku: 'PRICED-V',
        option_type: option_type.name,
        option_value: 'priced',
        price: 10,
        prices: [
          { currency: 'USD', amount: 25.00, compare_at_amount: 30.00 },
          { currency: 'EUR', amount: 22.00 }
        ]
      }
    end

    it 'creates prices via upsert' do
      expect(result).to be_success
      variant = result.value[:variant]
      expect(variant.prices.find_by(currency: 'USD').amount.to_f).to eq(25.00)
      expect(variant.prices.find_by(currency: 'USD').compare_at_amount.to_f).to eq(30.00)
      expect(variant.prices.find_by(currency: 'EUR').amount.to_f).to eq(22.00)
    end
  end

  describe 'with nested stock_items' do
    let!(:stock_location_1) { Spree::StockLocation.first || create(:stock_location) }
    let!(:stock_location_2) { create(:stock_location, name: 'Warehouse 2') }

    let(:params) do
      {
        sku: 'STOCKED-V',
        option_type: option_type.name,
        option_value: 'stocked',
        price: 10,
        stock_items: [
          { stock_location_id: stock_location_1.prefixed_id, count_on_hand: 50, backorderable: false },
          { stock_location_id: stock_location_2.prefixed_id, count_on_hand: 10, backorderable: true }
        ]
      }
    end

    it 'sets stock via upsert' do
      expect(result).to be_success
      variant = result.value[:variant]
      si1 = variant.stock_items.find_by(stock_location: stock_location_1)
      si2 = variant.stock_items.find_by(stock_location: stock_location_2)
      expect(si1.count_on_hand).to eq(50)
      expect(si1.backorderable).to eq(false)
      expect(si2.count_on_hand).to eq(10)
      expect(si2.backorderable).to eq(true)
    end
  end

  describe 'invalid stock_location prefixed ID' do
    let(:params) do
      {
        sku: 'BAD-LOC',
        option_type: option_type.name,
        option_value: 'badloc',
        price: 10,
        stock_items: [
          { stock_location_id: 'sloc_nonexistent', count_on_hand: 5 }
        ]
      }
    end

    it 'raises RecordNotFound' do
      expect { result }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'total_on_hand shortcut' do
    before { Spree::StockLocation.update_all(propagate_all_variants: true) }

    let(:params) { { sku: 'TOH-V', option_type: option_type.name, option_value: 'toh', price: 10, total_on_hand: 42 } }

    it 'sets stock on first stock item' do
      expect(result).to be_success
      expect(result.value[:variant].total_on_hand).to eq(42)
    end
  end

  describe 'total_on_hand ignored when stock_items present' do
    let!(:stock_location) { Spree::StockLocation.first || create(:stock_location) }

    let(:params) do
      {
        sku: 'BOTH-V',
        option_type: option_type.name,
        option_value: 'both',
        price: 10,
        total_on_hand: 99,
        stock_items: [
          { stock_location_id: stock_location.prefixed_id, count_on_hand: 5 }
        ]
      }
    end

    it 'uses stock_items, not total_on_hand' do
      expect(result).to be_success
      variant = result.value[:variant]
      expect(variant.stock_items.find_by(stock_location: stock_location).count_on_hand).to eq(5)
    end
  end

  describe 'option type auto-creation' do
    let(:params) { { sku: 'AUTO-OPT', price: 10, option_type: 'Material', option_value: 'Cotton' } }

    it 'creates option type and value if they do not exist' do
      expect(result).to be_success
      expect(Spree::OptionType.find_by(name: 'material')).to be_present
      expect(Spree::OptionValue.find_by(name: 'cotton')).to be_present
    end
  end

  describe 'prefixed tax_category_id' do
    let(:tax_category) { create(:tax_category) }
    let(:params) { { sku: 'TAX-V', option_type: option_type.name, option_value: 'taxed', price: 10, tax_category_id: tax_category.prefixed_id } }

    it 'resolves prefixed ID' do
      expect(result).to be_success
      expect(result.value[:variant].read_attribute(:tax_category_id)).to eq(tax_category.id)
    end
  end

  describe 'no prices or stock_items' do
    let(:params) { { sku: 'PLAIN-V', option_type: option_type.name, option_value: 'plain', price: 10 } }

    it 'creates variant without extra prices or stock changes' do
      expect(result).to be_success
      expect(result.value[:variant].sku).to eq('PLAIN-V')
    end
  end
end
