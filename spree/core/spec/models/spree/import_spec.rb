require 'spec_helper'

RSpec.describe Spree::Import, :job, type: :model do
  let(:store) { @default_store }
  let(:user) { create(:admin_user) }

  let(:csv_content) { File.read(File.join(Spree::Core::Engine.root, 'spec/fixtures/files', 'products_import.csv')) }
  let(:import) { build(:product_import, store: store, user: user) }

  it_behaves_like 'lifecycle events', factory: :product_import

  before do
    # Stub the file content reading since ActiveStorage doesn't persist files properly in transactional tests
    allow(import).to receive(:attachment_file_content).and_return(csv_content)
  end

  describe 'Validations' do
    context 'type validation' do
      it 'validates type is whitelisted' do
        import.type = 'InvalidType'
        expect(import).not_to be_valid
        expect(import.errors[:type].first).to include('is not included in the list')
      end

      it 'allows valid types' do
        import.type = 'Spree::Imports::Products'
        expect(import).to be_valid
      end
    end

    context 'attachment validation' do
      it 'validates attachment content type' do
        import.attachment.attach(
          io: StringIO.new('test'),
          filename: 'test.txt',
          content_type: 'text/plain'
        )
        expect(import).not_to be_valid
        expect(import.errors[:attachment].first).to include('content type')
      end
    end
  end

  describe 'status' do
    before { import.save! }

    it 'has no state machine' do
      expect(described_class).not_to respond_to(:state_machines)
    end

    it 'starts in pending status' do
      expect(import.status).to eq('pending')
    end

    it 'rejects an unknown status' do
      import.status = 'nonsense'
      expect(import).not_to be_valid
    end
  end

  describe '#model_class' do
    context 'for Products import' do
      it 'returns Spree::Product' do
        import.type = 'Spree::Imports::Products'
        expect(import.model_class).to eq(Spree::Product)
      end
    end

    context 'for Customers import' do
      it 'returns the user class' do
        import.type = 'Spree::Imports::Customers'
        expect(import.model_class).to eq(Spree.customer_class)
      end
    end
  end

  describe '#import_schema' do
    it 'returns the correct schema class' do
      import.type = 'Spree::Imports::Products'
      expect(import.import_schema).to be_a(Spree::ImportSchemas::Products)
    end
  end

  describe '#display_name' do
    before { import.save! } # need to generate the number

    it 'returns the correct display name' do
      expect(import.display_name).to match(/Products IM\d+/)
    end
  end

  describe '#csv_headers' do
    it 'returns the CSV headers' do
      expect(import.csv_headers).to eq([
                                         'slug',
                                         'sku',
                                         'name',
                                         'status',
                                         'seller_name',
                                         'brand_name',
                                         'description',
                                         'meta_title',
                                         'meta_description',
                                         'meta_keywords',
                                         'tags',
                                         'labels',
                                         'price',
                                         'compare_at_price',
                                         'currency',
                                         'width',
                                         'height',
                                         'depth',
                                         'dimensions_unit',
                                         'weight',
                                         'weight_unit',
                                         'available_on',
                                         'discontinue_on',
                                         'track_inventory',
                                         'inventory_count',
                                         'inventory_backorderable',
                                         'tax_category',
                                         'digital',
                                         'image1_src',
                                         'image2_src',
                                         'image3_src',
                                         'option1_name',
                                         'option1_value',
                                         'option2_name',
                                         'option2_value',
                                         'option3_name',
                                         'option3_value',
                                         'category1',
                                         'category2',
                                         'category3',
                                         'custom_field.properties.fit',
                                         'custom_field.properties.manufacturer',
                                         'custom_field.properties.material',
                                         'custom_field.custom.brand',
                                         'custom_field.custom.material'
                                       ])
    end

    context 'with custom delimiter' do
      let(:csv_content) { "slug;sku;name;price\ntest;SKU1;Test;9.99" }

      before { import.preferred_delimiter = ';' }

      it 'parses headers with custom delimiter' do
        expect(import.csv_headers).to eq(['slug', 'sku', 'name', 'price'])
      end
    end
  end

  describe '#schema_fields' do
    context 'when model supports custom_fields' do
      let!(:custom_field_definition1) do
        create(:custom_field_definition,
               namespace: 'properties',
               key: 'manufacturer',
               label: 'Manufacturer',
               resource_type: 'Spree::Product')
      end
      let!(:custom_field_definition2) do
        create(:custom_field_definition,
               namespace: 'custom',
               key: 'brand',
               label: 'Brand',
               resource_type: 'Spree::Product')
      end

      before do
        import.type = 'Spree::Imports::Products'
      end

      it 'returns base fields from schema' do
        base_fields = import.schema_fields.select { |f| !f[:name].start_with?('custom_field.') }
        expect(base_fields).to include(
          { name: 'slug', label: 'Slug', required: true },
          { name: 'sku', label: 'SKU', required: true },
          { name: 'name', label: 'Name', required: true }
        )
      end

      it 'includes custom_field fields' do
        custom_field_fields = import.schema_fields.select { |f| f[:name].start_with?('custom_field.') }
        expect(custom_field_fields).to include(
          { name: 'custom_field.properties.manufacturer', label: 'Manufacturer' },
          { name: 'custom_field.custom.brand', label: 'Brand' }
        )
      end

      it 'combines base fields and custom_field fields' do
        all_fields = import.schema_fields
        base_field_count = Spree::ImportSchemas::Products::FIELDS.count
        custom_field_count = 2

        expect(all_fields.count).to eq(base_field_count + custom_field_count)
      end

      it 'has correct structure for custom_field fields' do
        custom_field_field = import.schema_fields.find { |f| f[:name] == 'custom_field.properties.manufacturer' }
        expect(custom_field_field).to eq(
          { name: 'custom_field.properties.manufacturer', label: 'Manufacturer' }
        )
      end
    end

    context 'when model does not support custom_fields' do
      before do
        import.type = 'Spree::Imports::Products'
        # Mock model_class to return a class that doesn't include CustomFields
        allow(import).to receive(:model_class).and_return(double('ModelClass', included_modules: []))
      end

      it 'returns only base fields from schema' do
        fields = import.schema_fields
        expect(fields).to eq(Spree::ImportSchemas::Products::FIELDS)
      end

      it 'does not include any custom_field fields' do
        custom_field_fields = import.schema_fields.select { |f| f[:name].start_with?('custom_field.') }
        expect(custom_field_fields).to be_empty
      end
    end

    context 'when model supports custom_fields but has no custom_field definitions' do
      before do
        import.type = 'Spree::Imports::Products'
        # Ensure no custom_field definitions exist
        Spree::CustomFieldDefinition.where(resource_type: 'Spree::Product').delete_all
      end

      it 'returns only base fields' do
        fields = import.schema_fields
        expect(fields).to eq(Spree::ImportSchemas::Products::FIELDS)
      end
    end
  end

  describe 'mapping creation' do
    before { import.save! }

    it 'creates mappings for schema fields' do
      expect { Spree.import_start_mapping_workflow.call(import: import) }.to change { import.mappings.count }.from(0)
    end

    it 'auto-assigns file columns when possible' do
      Spree.import_start_mapping_workflow.call(import: import)
      slug_mapping = import.mappings.find_by(schema_field: 'slug')
      expect(slug_mapping.file_column).to eq('slug')
    end
  end

  describe '#unmapped_file_columns' do
    before do
      import.save!
      Spree.import_start_mapping_workflow.call(import: import)
      # Map only slug column
      import.mappings.find_by(schema_field: 'slug').update!(file_column: 'slug')
    end

    it 'returns columns that are not mapped' do
      expect(import.unmapped_file_columns).to include('seller_name', 'brand_name', 'labels', 'custom_field.properties.fit', 'custom_field.properties.manufacturer', 'custom_field.properties.material')
      expect(import.unmapped_file_columns).not_to include('slug')
    end
  end

  describe '#mapping_done?' do
    before do
      import.save!
    end

    context 'when all required fields are mapped' do
      before do
        Spree.import_start_mapping_workflow.call(import: import)
      end

      it 'returns true' do
        expect(import.mapping_done?).to be true
      end
    end

    context 'when not all required fields are mapped' do
      it 'returns false' do
        expect(import.mapping_done?).to be false
      end
    end
  end

  describe '#store' do
    context 'when owner is a Store' do
      it 'returns the owner' do
        expect(import.store).to eq(store)
      end
    end
  end

  describe '.available_types' do
    it 'returns configured import types' do
      expect(described_class.available_types).to eq(Spree.import_types)
    end
  end

  describe '.available_models' do
    it 'returns model classes for available types' do
      expect(described_class.available_models).to include(Spree::Product)
    end
  end

  describe '.type_for_model' do
    it 'returns the import type for a given model' do
      type = described_class.type_for_model(Spree::Product)
      expect(type.to_s).to eq('Spree::Imports::Products')
    end
  end

  describe '.model_class' do
    it 'returns the model class for the import type' do
      expect(Spree::Imports::Products.model_class).to eq(Spree::Product)
    end
  end

  describe '#template_csv' do
    it 'is the schema header row' do
      import = Spree::Imports::Products.new

      expect(import.template_csv.strip.split(',')).to include('slug', 'sku', 'name', 'price')
      expect(import.template_csv.lines.size).to eq(1)
    end

    it 'names the file after the type' do
      expect(Spree::Imports::Products.new.template_csv_filename).to eq('products_import_template.csv')
    end

    # The admin's new-import form builds a base Spree::Import with `type`
    # assigned, so both helpers have to read the column.
    it 'resolves from the type column on a base instance' do
      import = described_class.new(type: 'Spree::Imports::Customers')

      expect(import.template_csv_filename).to eq('customers_import_template.csv')
      expect(import.template_csv.strip.split(',')).to include('email')
    end
  end

  describe '#sample_csv_url' do
    it 'resolves from the type column on a base instance' do
      import = described_class.new(type: 'Spree::Imports::Products')

      expect(import.sample_csv_url).to end_with('/db/sample_data/products.csv')
    end
  end

  describe '.sample_csv_url' do
    it 'points at the example CSV for the type' do
      expect(Spree::Imports::Products.sample_csv_url).to end_with('/db/sample_data/products.csv')
      expect(Spree::Imports::Customers.sample_csv_url).to end_with('/db/sample_data/customers.csv')
      expect(Spree::Imports::ProductTranslations.sample_csv_url).to end_with('/db/sample_data/product_translations.csv')
    end

    # Pinned to the installed version, not `main` — the availability check reads
    # the local db/sample_data, so the served file has to match that schema.
    it 'pins the URL to the installed Spree version' do
      expect(Spree::Imports::Products.sample_csv_url).to eq(
        "https://raw.githubusercontent.com/spree/spree/refs/tags/v#{Spree.version}/spree/core/db/sample_data/products.csv"
      )
    end

    it 'is nil on the base class' do
      expect(described_class.sample_csv_url).to be_nil
    end

    # An import type whose example CSV was never added must not render a link
    # that 404s — the answer comes from db/sample_data, not a hardcoded list.
    it 'is nil for a type with no example file' do
      klass = Class.new(described_class) do
        def self.name
          'Spree::Imports::Orders'
        end
      end

      expect(klass.sample_csv_url).to be_nil
    end
  end

  describe 'custom events', :events do
    describe 'import.completed' do
      before do
        import.save!
        Spree.import_start_mapping_workflow.call(import: import)
        Spree.import_complete_mapping_workflow.call(import: import)
        Spree.import_start_processing_workflow.call(import: import)
      end

      it 'publishes import.completed event when completed' do
        expect(import).to receive(:publish_event).with('import.completed')
        allow(import).to receive(:publish_event).with(anything)

        Spree.import_complete_workflow.call(import: import)
      end
    end
  end
end
