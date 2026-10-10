require 'spec_helper'

RSpec.describe Spree::ImportMapping, type: :model do
  let(:store) { @default_store }
  let(:user) { create(:admin_user) }
  let(:import) { create(:product_import, store: store, user: user) }

  describe '#required?' do
    context 'when schema_field is a required field' do
      let(:mapping) { build(:import_mapping, import: import, schema_field: 'slug') }

      it 'returns true' do
        expect(mapping.required?).to be true
      end
    end

    context 'when schema_field is not a required field' do
      let(:mapping) { build(:import_mapping, import: import, schema_field: 'description') }

      it 'returns false' do
        expect(mapping.required?).to be false
      end
    end
  end

  describe '#mapped?' do
    context 'when file_column is present' do
      let(:mapping) { build(:import_mapping, import: import, file_column: 'product_name') }

      it 'returns true' do
        expect(mapping.mapped?).to be true
      end
    end

    context 'when file_column is blank' do
      let(:mapping) { build(:import_mapping, import: import, file_column: nil) }

      it 'returns false' do
        expect(mapping.mapped?).to be false
      end

      it 'returns false when file_column is empty string' do
        mapping.file_column = ''
        expect(mapping.mapped?).to be false
      end
    end
  end

  describe '#try_to_auto_assign_file_column' do
    let(:mapping) { create(:import_mapping, import: import, schema_field: 'slug', file_column: nil) }
    let(:csv_headers) { ['Product Name', 'Slug', 'SKU', 'Price'] }

    context 'when exact match exists' do
      it 'assigns the matching file column' do
        mapping.try_to_auto_assign_file_column(csv_headers)
        expect(mapping.file_column).to eq('Slug')
      end
    end

    context 'when case-insensitive match exists' do
      let(:csv_headers) { ['product name', 'SLUG', 'sku', 'price'] }

      it 'assigns the matching file column' do
        mapping.try_to_auto_assign_file_column(csv_headers)
        expect(mapping.file_column).to eq('SLUG')
      end
    end

    context 'when parameterized match exists' do
      let(:mapping) { build(:import_mapping, import: import, schema_field: 'product_name', file_column: nil) }
      let(:csv_headers) { ['Product Name', 'Slug', 'SKU'] }

      it 'assigns the matching file column' do
        mapping.try_to_auto_assign_file_column(csv_headers)
        expect(mapping.file_column).to eq('Product Name')
      end
    end

    context 'when no match exists' do
      let(:csv_headers) { ['Product Name', 'Title', 'SKU', 'Price'] }

      it 'does not assign a file column' do
        mapping.try_to_auto_assign_file_column(csv_headers)
        expect(mapping.file_column).to be_nil
      end
    end

    context 'when file_column is already set' do
      let(:mapping) { build(:import_mapping, import: import, schema_field: 'slug', file_column: 'custom_column') }
      let(:csv_headers) { ['Slug', 'SKU'] }

      it 'overwrites with matching column' do
        mapping.try_to_auto_assign_file_column(csv_headers)
        expect(mapping.file_column).to eq('Slug')
      end
    end
  end

  describe '#schema_field_label' do
    context 'when schema_field exists in import schema' do
      let(:mapping) { build(:import_mapping, import: import, schema_field: 'slug') }

      it 'returns the label for the schema field' do
        expect(mapping.schema_field_label).to eq('Slug')
      end
    end

    context 'when schema_field is a custom_field' do
      let!(:custom_field_definition) do
        create(:custom_field_definition,
               namespace: 'properties',
               key: 'manufacturer',
               label: 'Manufacturer',
               resource_type: 'Spree::Product')
      end
      let(:mapping) do
        create(:import_mapping,
               import: import,
               schema_field: 'custom_field.properties.manufacturer')
      end

      it 'returns the custom_field definition name' do
        expect(mapping.schema_field_label).to eq('Manufacturer')
      end
    end

    context 'when schema_field does not exist in import schema' do
      let(:mapping) { build(:import_mapping, import: import, schema_field: 'non_existent_field') }

      it 'returns nil' do
        expect(mapping.schema_field_label).to be_nil
      end
    end
  end
end
