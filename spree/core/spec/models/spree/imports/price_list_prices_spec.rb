require 'spec_helper'

RSpec.describe Spree::Imports::PriceListPrices, type: :model do
  let(:store) { @default_store }
  let(:price_list) { create(:price_list, store: store) }
  let(:import) { create(:price_list_prices_import, store: store, price_list: price_list) }

  it 'processes rows with the price-list row processor, grouped by SKU' do
    expect(import.row_processor_class).to eq(Spree::Imports::RowProcessors::PriceListPrice)
    expect(import.group_column).to eq('sku')
    expect(import.import_schema).to be_a(Spree::ImportSchemas::PriceListPrices)
    expect(import.model_class).to eq(Spree::Price)
    expect(described_class.required_scope).to eq(:products)
  end

  describe '#price_list' do
    it 'reads the list through the store' do
      expect(import.price_list).to eq(price_list)

      foreign = create(:price_list, store: create(:store))
      import.price_list = foreign
      expect(import.price_list).to be_nil
    end

    it 'is required to create the import, and only then' do
      fresh = described_class.new(store: store, user: create(:admin_user))
      expect(fresh).not_to be_valid
      expect(fresh.errors[:price_list]).to be_present

      # A list deleted mid-run must not pin the import in `processing`.
      running = import
      price_list.destroy!
      expect(running.reload.update(status: 'completed')).to be(true)
    end
  end
end
