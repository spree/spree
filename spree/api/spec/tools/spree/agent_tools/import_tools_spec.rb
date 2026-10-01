require 'spec_helper'
require 'csv'

RSpec.describe 'assistant import tools' do
  let(:store) { @default_store }
  let(:admin) { create(:admin_user) }
  let(:context) { Spree::AgentTools::Context.new(store: store, user: admin, ability: ability) }
  let(:ability) do
    Class.new do
      include CanCan::Ability
      def initialize = can(:manage, :all)
      def permission_keys = Spree.permissions.catalog_keys
    end.new
  end

  # A spreadsheet with the headings a real merchant would send: none of them
  # match a Spree field name, which is the whole reason this feature exists.
  let(:csv) do
    CSV.generate do |rows|
      rows << ['Handle', 'Product Title', 'Item Code', 'Retail Price (inc VAT)']
      rows << ['blue-shirt', 'Blue Shirt', 'BS-1', '29.00']
    end
  end

  let(:import) do
    record = Spree::Imports::Products.new(owner: store, user: admin)
    record.attachment.attach(io: StringIO.new(csv), filename: 'messy.csv', content_type: 'text/csv')
    record.save!
    record.start_mapping!
    record
  end

  describe Spree::AgentTools::DescribeImportMapping do
    it 'hands the model the real headings and the real field names' do
      result = described_class.new(context).call(id: import.prefixed_id)

      expect(result[:file_columns]).to include('Product Title', 'Item Code')
      expect(result[:spree_fields].map { |field| field[:field] }).to include('name', 'sku', 'price')
      expect(result[:spree_fields].select { |field| field[:required] }.map { |f| f[:field] })
        .to contain_exactly('slug', 'sku', 'name', 'price')
    end
  end

  describe Spree::AgentTools::ProposeImportMapping do
    subject(:tool) { described_class.new(context) }

    it 'is held for approval rather than applied outright' do
      expect(described_class.mutating?).to be(true)
    end

    it 'applies a mapping and reports what is still missing' do
      result = tool.call(id: import.prefixed_id,
                         mapping: { 'name' => 'Product Title', 'sku' => 'Item Code' })

      expect(result[:ok]).to be(true)
      expect(import.mappings.find_by(schema_field: 'name').file_column).to eq('Product Title')
      expect(result[:still_missing]).to contain_exactly('slug', 'price')
    end

    it 'starts the import once every required field is mapped' do
      import.update!(preferred_inline: true)

      tool.call(id: import.prefixed_id,
                mapping: { 'slug' => 'Handle', 'name' => 'Product Title',
                           'sku' => 'Item Code', 'price' => 'Retail Price (inc VAT)' })

      expect(import.reload.status).to eq('completed')
    end

    it 'refuses a field or column that does not exist' do
      # The model is guessing at a messy file; an invented pairing must not
      # reach the database, and it needs the real vocabulary to correct itself.
      result = tool.call(id: import.prefixed_id,
                         mapping: { 'invented' => 'Product Title', 'name' => 'No Such Column' })

      expect(result[:error]).to be_present
      expect(result[:spree_fields]).to include('name')
      expect(import.mappings.find_by(schema_field: 'name').file_column).to be_blank
    end

    it 'names the pairing on the approval card' do
      summary = tool.summary(id: import.prefixed_id, mapping: { 'name' => 'Product Title' })

      # The merchant judges this sentence, so it reads as the pairing itself.
      expect(summary).to eq('Map Product Title → name')
    end
  end

  describe Spree::AgentTools::GetImportStatus do
    it 'reports row counts for the latest import' do
      import

      result = described_class.new(context).call

      expect(result[:number]).to eq(import.number)
      expect(result[:status]).to eq('mapping')
    end
  end

  # An import holds the uploaded file — its headings, a real sample row, the
  # rows that failed. Reading that is reading the resource being imported, so
  # `read_settings` alone must not open a customer list someone uploaded.
  describe 'reading an import the caller may not read' do
    let(:ability) do
      Class.new do
        include CanCan::Ability
        def initialize = can(:manage, :all)
        def permission_keys = %w[read_settings write_settings]
      end.new
    end

    it 'refuses to describe its mapping' do
      result = Spree::AgentTools::DescribeImportMapping.new(context).call(id: import.prefixed_id)

      expect(result[:error]).to be_present
      expect(result).not_to have_key(:sample_row)
    end

    it 'refuses to report its status' do
      result = Spree::AgentTools::GetImportStatus.new(context).call(id: import.prefixed_id)

      expect(result[:error]).to be_present
    end
  end
end
