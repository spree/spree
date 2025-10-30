require 'spec_helper'

RSpec.describe Spree::ImportMapping, type: :model do
  let(:store) { @default_store }
  let(:user) { create(:admin_user) }
  let(:import) { create(:product_import, owner: store, user: user) }

  describe 'Associations' do
    it { is_expected.to belong_to(:import) }
  end

  describe 'Validations' do
    describe 'presence validations' do
      it 'validates presence of import' do
        mapping = build(:import_mapping, import: nil)
        expect(mapping).not_to be_valid
        expect(mapping.errors[:import]).to include("can't be blank")
      end

      it 'validates presence of schema_field' do
        mapping = build(:import_mapping, schema_field: nil)
        expect(mapping).not_to be_valid
        expect(mapping.errors[:schema_field]).to include("can't be blank")
      end
    end

    describe 'uniqueness validations' do
      let!(:existing_mapping) { create(:import_mapping, import: import, schema_field: 'slug') }

      it 'validates uniqueness of schema_field scoped to import_id' do
        duplicate_mapping = build(:import_mapping, import: import, schema_field: 'slug')
        expect(duplicate_mapping).not_to be_valid
        expect(duplicate_mapping.errors[:schema_field]).to include('has already been taken')
      end

      it 'allows same schema_field for different imports' do
        other_import = create(:product_import, owner: store, user: user)
        duplicate_mapping = build(:import_mapping, import: other_import, schema_field: 'slug')
        expect(duplicate_mapping).to be_valid
      end

      it 'validates uniqueness of file_column scoped to import_id' do
        existing_mapping.update!(file_column: 'product_name')
        duplicate_mapping = build(:import_mapping, import: import, file_column: 'product_name')
        expect(duplicate_mapping).not_to be_valid
        expect(duplicate_mapping.errors[:file_column]).to include('has already been taken')
      end

      it 'allows blank file_column' do
        mapping = build(:import_mapping, import: import, schema_field: 'description', file_column: nil)
        expect(mapping).to be_valid
      end

      it 'allows same file_column for different imports' do
        other_import = create(:product_import, owner: store, user: user)
        mapping = build(:import_mapping, import: other_import, schema_field: 'sku', file_column: 'name')
        expect(mapping).to be_valid
      end
    end
  end

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

    context 'when schema_field is a metafield' do
      let!(:metafield_definition) do
        create(:metafield_definition,
               namespace: 'properties',
               key: 'manufacturer',
               name: 'Manufacturer',
               resource_type: 'Spree::Product')
      end
      let(:mapping) do
        create(:import_mapping,
               import: import,
               schema_field: 'metafield.properties.manufacturer')
      end

      it 'returns the metafield definition name' do
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
