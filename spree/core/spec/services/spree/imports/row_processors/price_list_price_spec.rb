require 'spec_helper'

RSpec.describe Spree::Imports::RowProcessors::PriceListPrice, type: :service do
  subject { described_class.new(row) }

  let(:store) { @default_store }
  let(:price_list) { create(:price_list, store: store) }
  let(:import) { create(:price_list_prices_import, store: store, price_list: price_list) }
  let(:row) { create(:import_row, import: import, data: row_data.to_json) }
  let(:csv_row_headers) { Spree::ImportSchemas::PriceListPrices.new.headers }

  let(:product) { create(:product, store: store) }
  let!(:variant) { create(:variant, product: product, sku: 'DENIM-M') }

  before do
    Spree.import_start_mapping_workflow.call(import: import)
  end

  def csv_row_hash(attrs = {})
    csv_row_headers.index_with { |header| attrs[header] }
  end

  def rung(quantity, currency: 'USD')
    price_list.prices.find_by(variant: variant, currency: currency, min_quantity: quantity)
  end

  context 'with a bottom rung' do
    let(:row_data) { csv_row_hash('sku' => 'DENIM-M', 'currency' => 'usd', 'price' => '18.00', 'compare_at_price' => '20') }

    it 'writes the price on the list and links the row to the variant' do
      expect(subject.process!).to eq(variant)

      expect(rung(1).amount).to eq(18)
      expect(rung(1).compare_at_amount).to eq(20)
    end
  end

  context 'with a quantity break' do
    let(:row_data) { csv_row_hash('sku' => 'denim-m', 'min_quantity' => '24', 'price' => '16.50') }

    it 'writes the rung in the store\'s default currency, matching the SKU regardless of case' do
      subject.process!

      expect(rung(24).amount).to eq(16.5)
      expect(rung(1)).to be_nil
    end
  end

  context 'with a blank price' do
    let(:row_data) { csv_row_hash('sku' => 'DENIM-M', 'currency' => 'USD', 'min_quantity' => '24', 'price' => '') }

    before { create(:price, variant: variant, price_list: price_list, currency: 'USD', min_quantity: 24, amount: 16.5) }

    it 'removes that rung' do
      expect(subject.process!).to eq(variant)
      expect(rung(24)).to be_nil
    end
  end

  context 'when the file has no compare-at column' do
    let(:row_data) { csv_row_hash('sku' => 'DENIM-M', 'currency' => 'USD', 'price' => '17') }

    before do
      create(:price, variant: variant, price_list: price_list, currency: 'USD', min_quantity: 1, amount: 18, compare_at_amount: 20)
      import.mappings.find_by(schema_field: 'compare_at_price').update!(file_column: nil)
    end

    it 'keeps the rung\'s compare-at price' do
      subject.process!

      expect(rung(1).amount).to eq(17)
      expect(rung(1).compare_at_amount).to eq(20)
    end
  end

  context 'when the price uses a comma or a currency sign' do
    let(:row_data) { csv_row_hash('sku' => 'DENIM-M', 'price' => '$1,650.00') }

    it 'fails the row rather than guessing the locale' do
      expect { subject.process! }.to raise_error(ArgumentError, /price must be/)
    end
  end

  context 'when the SKU is unknown to the store' do
    let(:row_data) { csv_row_hash('sku' => 'NOPE', 'price' => '1') }

    it 'fails the row' do
      expect { subject.process! }.to raise_error(ArgumentError, /NOPE/)
    end
  end

  context 'when the SKU is shared by two sellers\' listings' do
    let(:row_data) { csv_row_hash('sku' => 'DENIM-M', 'price' => '1') }

    before do
      other = create(:product, store: store, seller: create(:seller, store: store))
      create(:variant, product: other, sku: 'DENIM-M')
    end

    it 'fails the row rather than guessing' do
      expect { subject.process! }.to raise_error(ArgumentError, /More than one/)
    end
  end

  context 'when the currency is not one the store sells in' do
    let(:row_data) { csv_row_hash('sku' => 'DENIM-M', 'currency' => 'JPY', 'price' => '1') }

    it 'fails the row' do
      expect { subject.process! }.to raise_error(ArgumentError, /JPY/)
    end
  end

  context 'when the price is negative' do
    let(:row_data) { csv_row_hash('sku' => 'DENIM-M', 'price' => '-5') }

    it 'fails the row' do
      expect { subject.process! }.to raise_error(ArgumentError, /price must be/)
    end
  end

  context 'when the price is text the parser would read as zero' do
    let(:row_data) { csv_row_hash('sku' => 'DENIM-M', 'price' => 'n/a') }

    it 'fails the row instead of pricing the rung at zero' do
      expect { subject.process! }.to raise_error(ArgumentError, /price must be/)
      expect(rung(1)).to be_nil
    end
  end

  context 'when the quantity is not a whole number of units' do
    let(:row_data) { csv_row_hash('sku' => 'DENIM-M', 'min_quantity' => '2.5', 'price' => '1') }

    it 'fails the row' do
      expect { subject.process! }.to raise_error(ArgumentError, /whole number/)
    end
  end

  context 'when the ladder is at the cap' do
    let(:row_data) { csv_row_hash('sku' => 'DENIM-M', 'min_quantity' => '999', 'price' => '1') }

    before do
      (2..(Spree::Price::MAXIMUM_BREAKS_PER_VARIANT + 1)).each do |quantity|
        create(:price, variant: variant, price_list: price_list, currency: 'USD', min_quantity: quantity, amount: 1)
      end
    end

    it 'refuses the eleventh break' do
      expect { subject.process! }.to raise_error(ArgumentError, /at most #{Spree::Price::MAXIMUM_BREAKS_PER_VARIANT}/)
    end
  end

  context 'when the import has lost its price list' do
    let(:row_data) { csv_row_hash('sku' => 'DENIM-M', 'price' => '1') }

    before { price_list.destroy! }

    it 'fails the row' do
      expect { subject.process! }.to raise_error(ArgumentError, /not attached/)
    end
  end
end
