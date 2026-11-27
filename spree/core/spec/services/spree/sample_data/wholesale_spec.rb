require 'spec_helper'

# db/sample_data/wholesale.rb, loaded on its own: the full loader run in
# loader_spec.rb covers a store selling in USD, the currency the sample files
# price in.
RSpec.describe 'Wholesale sample data' do
  let(:store) { @default_store }
  let(:wholesale_file) { Spree::Core::Engine.root.join('db', 'sample_data', 'wholesale.rb').to_s }

  def load_wholesale
    Spree::Current.set(store: store) { load wholesale_file }
  end

  context 'when the store does not sell in the currency of the example price-list file' do
    before do
      allow(store).to receive(:supported_currencies_list).and_return([Money::Currency.find('GBP')])
    end

    it 'skips the quantity breaks instead of failing the sample data run' do
      expect(Spree::SampleData::ImportRunner).not_to receive(:new)

      expect { load_wholesale }.to output(/Skipping wholesale quantity breaks/).to_stdout

      expect(store.companies.find_by(name: 'Acme EMEA')).to be_present
    end
  end

  context 'when the store sells in some of the file currencies' do
    before do
      allow(store).to receive(:supported_currencies_list).
        and_return([Money::Currency.find('USD'), Money::Currency.find('GBP')])
    end

    it 'imports only the rows in those currencies' do
      # A mixed file, so filtering has to keep some rows and drop others
      # rather than take or skip the whole file.
      example_rows = CSV.parse(<<~CSV, headers: true)
        sku,currency,min_quantity,price,compare_at_price
        SKU-A,USD,12,9.99,
        SKU-A,EUR,12,8.99,
        SKU-B,usd,24,4.99,
        SKU-B,EUR,24,3.99,
      CSV
      allow(CSV).to receive(:read).and_call_original
      allow(CSV).to receive(:read).
        with(satisfy { |path| path.to_s.end_with?('db/sample_data/price_list_prices.csv') }, headers: true).
        and_return(example_rows)

      imported = nil
      runner = double(Spree::SampleData::ImportRunner)
      allow(Spree::SampleData::ImportRunner).to receive(:new).and_return(runner)
      allow(runner).to receive(:call) do |csv_path:, **|
        imported = CSV.read(csv_path, headers: true)
        Spree::ServiceModule::Result.new(true, double(rows: double(failed: Spree::ImportRow.none)))
      end

      load_wholesale

      expect(imported.map { |row| [row['sku'], row['currency']] }).to eq([%w[SKU-A USD], %w[SKU-B usd]])
    end
  end
end
