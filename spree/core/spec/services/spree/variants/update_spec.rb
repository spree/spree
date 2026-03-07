require 'spec_helper'

RSpec.describe Spree::Variants::Update do
  subject(:result) { described_class.call(variant: variant, params: params) }

  let(:store) { @default_store }
  let!(:product) { create(:product, stores: [store]) }
  let!(:variant) { create(:variant, product: product) }

  describe 'basic update' do
    let(:params) { { sku: 'UPDATED-SKU' } }

    it 'updates variant attributes' do
      expect(result).to be_success
      expect(result.value[:variant].sku).to eq('UPDATED-SKU')
    end
  end

  describe 'validation error' do
    let!(:other_variant) { create(:variant, product: product, sku: 'TAKEN') }
    let(:params) { { sku: 'TAKEN' } }

    it 'returns failure for duplicate sku' do
      expect(result).not_to be_success
    end
  end

  describe 'sync prices' do
    let(:params) do
      {
        prices: [
          { currency: 'USD', amount: 50.00, compare_at_amount: 60.00 },
          { currency: 'GBP', amount: 40.00 }
        ]
      }
    end

    it 'creates new prices' do
      expect(result).to be_success
      variant.reload
      expect(variant.prices.find_by(currency: 'USD').amount.to_f).to eq(50.00)
      expect(variant.prices.find_by(currency: 'GBP').amount.to_f).to eq(40.00)
    end
  end

  describe 'sync prices removes missing currencies' do
    before do
      variant.prices.create!(currency: 'EUR', amount: 20)
      variant.prices.create!(currency: 'GBP', amount: 15)
    end

    let(:params) do
      {
        prices: [
          { currency: 'EUR', amount: 25.00 }
        ]
      }
    end

    it 'soft-deletes GBP price and updates EUR' do
      expect(result).to be_success
      variant.reload
      expect(variant.prices.find_by(currency: 'EUR').amount.to_f).to eq(25.00)
      # GBP should be soft-deleted
      gbp = Spree::Price.with_deleted.find_by(variant_id: variant.id, currency: 'GBP')
      expect(gbp.deleted_at).to be_present
    end
  end

  describe 'sync stock_items' do
    let!(:stock_location) { Spree::StockLocation.first || create(:stock_location) }

    let(:params) do
      {
        stock_items: [
          { stock_location_id: stock_location.prefixed_id, count_on_hand: 100, backorderable: true }
        ]
      }
    end

    it 'sets stock levels' do
      expect(result).to be_success
      si = variant.reload.stock_items.find_by(stock_location: stock_location)
      expect(si.count_on_hand).to eq(100)
      expect(si.backorderable).to eq(true)
    end
  end

  describe 'sync stock_items removes missing locations' do
    let!(:loc1) { Spree::StockLocation.first || create(:stock_location) }
    let!(:loc2) { create(:stock_location, name: 'Secondary') }

    before do
      variant.stock_items.find_or_create_by!(stock_location: loc1).update!(count_on_hand: 10)
      variant.stock_items.find_or_create_by!(stock_location: loc2).update!(count_on_hand: 20)
    end

    let(:params) do
      {
        stock_items: [
          { stock_location_id: loc1.prefixed_id, count_on_hand: 50 }
        ]
      }
    end

    it 'soft-deletes stock item for loc2' do
      expect(result).to be_success
      variant.reload
      expect(variant.stock_items.find_by(stock_location: loc1).count_on_hand).to eq(50)
      deleted_si = Spree::StockItem.with_deleted.find_by(variant_id: variant.id, stock_location_id: loc2.id)
      expect(deleted_si.deleted_at).to be_present
    end
  end

  describe 'option value reassignment' do
    let(:params) { { option_type: 'Color', option_value: 'Blue' } }

    it 'assigns new option value' do
      expect(result).to be_success
      expect(result.value[:variant].option_values.map(&:presentation)).to include('Blue')
    end
  end

  describe 'no prices or stock params' do
    let(:params) { { weight: 2.5 } }

    it 'updates only variant attributes' do
      expect(result).to be_success
      expect(result.value[:variant].weight.to_f).to eq(2.5)
    end
  end
end
