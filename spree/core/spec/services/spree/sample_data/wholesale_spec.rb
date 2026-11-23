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
      imported = nil
      runner = double(Spree::SampleData::ImportRunner)
      allow(Spree::SampleData::ImportRunner).to receive(:new).and_return(runner)
      allow(runner).to receive(:call) do |csv_path:, **|
        imported = CSV.read(csv_path, headers: true)
        Spree::ServiceModule::Result.new(true, double(rows: double(failed: Spree::ImportRow.none)))
      end

      load_wholesale

      expect(imported).to be_present
      expect(imported['currency'].uniq).to eq(['USD'])
    end
  end
end
