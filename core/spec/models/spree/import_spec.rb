require 'spec_helper'

RSpec.describe Spree::Import, :job, type: :model do
  let(:store) { @default_store }
  let(:user) { create(:admin_user) }

  let(:csv_content) { File.read(File.join(Spree::Core::Engine.root, 'spec/fixtures/files', 'products_import.csv')) }
  let(:import) { build(:product_import, owner: store, user: user) }

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

  describe 'State machine' do
    before { import.save! }

    describe 'initial state' do
      it 'starts in pending state' do
        expect(import.status).to eq('pending')
      end
    end

    describe 'start_mapping event' do
      it 'transitions from pending to mapping' do
        expect { import.start_mapping! }.to change(import, :status).from('pending').to('mapping')
      end

      it 'creates mappings before transition' do
        expect { import.start_mapping! }.to change { import.mappings.count }.from(0)
      end
    end

    describe 'complete_mapping event' do
      before { import.start_mapping! }

      it 'transitions from mapping to completed_mapping' do
        expect { import.complete_mapping! }.to change(import, :status).from('mapping').to('completed_mapping')
      end

      it 'creates rows asynchronously after transition' do
        expect(import).to receive(:create_rows_async)
        import.complete_mapping!
      end
    end

    describe 'start_processing event' do
      before do
        import.start_mapping!
        import.complete_mapping!
      end

      it 'transitions from completed_mapping to processing' do
        expect { import.start_processing! }.to change(import, :status).from('completed_mapping').to('processing')
      end
    end

    describe 'complete event' do
      before do
        import.start_mapping!
        import.complete_mapping!
        import.start_processing!
      end

      it 'transitions from processing to completed' do
        expect { import.complete! }.to change(import, :status).from('processing').to('completed')
      end

      it 'sends import completed email after transition' do
        expect(import).to receive(:send_import_completed_email)
        import.complete!
      end

      it 'updates loader in import view after transition' do
        expect(import).to receive(:update_loader_in_import_view)
        import.complete!
      end
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
        expect(import.model_class).to eq(Spree.user_class)
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
        'vendor_name',
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
        'metafield.properties.fit',
        'metafield.properties.manufacturer',
        'metafield.properties.material',
        'metafield.custom.brand',
        'metafield.custom.material'
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
    context 'when model supports metafields' do
      let!(:metafield_definition1) do
        create(:metafield_definition,
               namespace: 'properties',
               key: 'manufacturer',
               name: 'Manufacturer',
               resource_type: 'Spree::Product')
      end
      let!(:metafield_definition2) do
        create(:metafield_definition,
               namespace: 'custom',
               key: 'brand',
               name: 'Brand',
               resource_type: 'Spree::Product')
      end

      before do
        import.type = 'Spree::Imports::Products'
      end

      it 'returns base fields from schema' do
        base_fields = import.schema_fields.select { |f| !f[:name].start_with?('metafield.') }
        expect(base_fields).to include(
          { name: 'slug', label: 'Slug', required: true },
          { name: 'sku', label: 'SKU', required: true },
          { name: 'name', label: 'Name', required: true }
        )
      end

      it 'includes metafield fields' do
        metafield_fields = import.schema_fields.select { |f| f[:name].start_with?('metafield.') }
        expect(metafield_fields).to include(
          { name: 'metafield.properties.manufacturer', label: 'Manufacturer' },
          { name: 'metafield.custom.brand', label: 'Brand' }
        )
      end

      it 'combines base fields and metafield fields' do
        all_fields = import.schema_fields
        base_field_count = Spree::ImportSchemas::Products::FIELDS.count
        metafield_count = 2

        expect(all_fields.count).to eq(base_field_count + metafield_count)
      end

      it 'has correct structure for metafield fields' do
        metafield_field = import.schema_fields.find { |f| f[:name] == 'metafield.properties.manufacturer' }
        expect(metafield_field).to eq(
          { name: 'metafield.properties.manufacturer', label: 'Manufacturer' }
        )
      end
    end

    context 'when model does not support metafields' do
      before do
        import.type = 'Spree::Imports::Products'
        # Mock model_class to return a class that doesn't include Metafields
        allow(import).to receive(:model_class).and_return(double('ModelClass', included_modules: []))
      end

      it 'returns only base fields from schema' do
        fields = import.schema_fields
        expect(fields).to eq(Spree::ImportSchemas::Products::FIELDS)
      end

      it 'does not include any metafield fields' do
        metafield_fields = import.schema_fields.select { |f| f[:name].start_with?('metafield.') }
        expect(metafield_fields).to be_empty
      end
    end

    context 'when model supports metafields but has no metafield definitions' do
      before do
        import.type = 'Spree::Imports::Products'
        # Ensure no metafield definitions exist
        Spree::MetafieldDefinition.where(resource_type: 'Spree::Product').destroy_all
      end

      it 'returns only base fields' do
        fields = import.schema_fields
        expect(fields).to eq(Spree::ImportSchemas::Products::FIELDS)
      end
    end
  end

  describe '#create_mappings' do
    before { import.save! }

    it 'creates mappings for schema fields' do
      expect { import.create_mappings }.to change { import.mappings.count }.from(0)
    end

    it 'auto-assigns file columns when possible' do
      import.create_mappings
      slug_mapping = import.mappings.find_by(schema_field: 'slug')
      expect(slug_mapping.file_column).to eq('slug')
    end
  end

  describe '#unmapped_file_columns' do
    before do
      import.save!
      import.create_mappings
      # Map only slug column
      import.mappings.find_by(schema_field: 'slug').update!(file_column: 'slug')
    end

    it 'returns columns that are not mapped' do
      expect(import.unmapped_file_columns).to include("vendor_name", "brand_name", "labels", "metafield.properties.fit", "metafield.properties.manufacturer", "metafield.properties.material")
      expect(import.unmapped_file_columns).not_to include('slug')
    end
  end

  describe '#mapping_done?' do
    before do
      import.save!
    end

    context 'when all required fields are mapped' do
      before do
        import.create_mappings
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

  describe '#create_rows_async' do
    before { import.save! }

    it 'enqueues CreateRowsJob' do
      expect { import.create_rows_async }.to have_enqueued_job(Spree::Imports::CreateRowsJob).with(import.id)
    end
  end

  describe '#process_rows_async' do
    before { import.save! }

    it 'enqueues ProcessRowsJob' do
      expect { import.process_rows_async }.to have_enqueued_job(Spree::Imports::ProcessRowsJob).with(import.id)
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
end
