require 'spec_helper'

RSpec.describe Spree::Admin::Table::Column do
  describe '#initialize' do
    it 'sets default values' do
      column = described_class.new(key: 'name', label: :name)

      expect(column.key).to eq('name')
      expect(column.type).to eq('string')
      expect(column.filter_type).to eq('string')
      expect(column.sortable).to be true
      expect(column.filterable).to be true
      expect(column.displayable).to be true
      expect(column.default).to be false
      expect(column.align).to eq('left')
      expect(column.ransack_attribute).to eq('name')
    end

    it 'accepts custom options' do
      column = described_class.new(
        key: 'price',
        label: 'Product Price',
        type: 'currency',
        sortable: false,
        filterable: true,
        default: true,
        position: 10,
        align: 'right',
        ransack_attribute: 'master_price'
      )

      expect(column.label).to eq('Product Price')
      expect(column.type).to eq('currency')
      expect(column.filter_type).to eq('currency')
      expect(column.sortable).to be false
      expect(column.default).to be true
      expect(column.position).to eq(10)
      expect(column.align).to eq('right')
      expect(column.ransack_attribute).to eq('master_price')
    end

    it 'uses type as filter_type by default' do
      column = described_class.new(key: 'status', label: :status, type: 'status')

      expect(column.filter_type).to eq('status')
    end

    it 'sets filter_type to nil when type has no corresponding filter_type' do
      column = described_class.new(key: 'status', label: :status, type: 'custom')

      expect(column.type).to eq('custom')
      expect(column.filter_type).to be_nil
    end

    it 'allows different filter_type than type when both are valid' do
      column = described_class.new(key: 'status', label: :status, type: 'string', filter_type: 'autocomplete')

      expect(column.type).to eq('string')
      expect(column.filter_type).to eq('autocomplete')
    end
  end

  describe 'validations' do
    it 'is invalid when label is missing' do
      column = described_class.new(key: 'name')
      expect(column).not_to be_valid
      expect(column.errors[:label]).to include("can't be blank")
    end

    it 'is invalid when type is invalid' do
      column = described_class.new(key: 'name', label: :name, type: 'invalid_type')
      expect(column).not_to be_valid
      expect(column.errors[:type]).to include("is not included in the list")
    end

    it 'accepts all valid types' do
      Spree::Admin::Table::Column::TYPES.each do |type|
        column = described_class.new(key: 'test', label: :test, type: type)
        expect(column).to be_valid
      end
    end
  end

  describe '#sortable?' do
    it 'returns true when sortable' do
      column = described_class.new(key: 'name', label: :name, sortable: true)
      expect(column.sortable?).to be true
    end

    it 'returns false when not sortable' do
      column = described_class.new(key: 'name', label: :name, sortable: false)
      expect(column.sortable?).to be false
    end
  end

  describe '#filterable?' do
    it 'returns true when filterable' do
      column = described_class.new(key: 'name', label: :name, filterable: true)
      expect(column.filterable?).to be true
    end

    it 'returns false when not filterable' do
      column = described_class.new(key: 'name', label: :name, filterable: false)
      expect(column.filterable?).to be false
    end
  end

  describe '#default?' do
    it 'returns true when default' do
      column = described_class.new(key: 'name', label: :name, default: true)
      expect(column.default?).to be true
    end

    it 'returns false when not default' do
      column = described_class.new(key: 'name', label: :name, default: false)
      expect(column.default?).to be false
    end
  end

  describe '#custom_sort?' do
    it 'returns true when sort_scope_asc is present' do
      column = described_class.new(key: 'price', label: :price, sort_scope_asc: :ascend_by_price)
      expect(column.custom_sort?).to be true
    end

    it 'returns true when sort_scope_desc is present' do
      column = described_class.new(key: 'price', label: :price, sort_scope_desc: :descend_by_price)
      expect(column.custom_sort?).to be true
    end

    it 'returns false when no sort scopes' do
      column = described_class.new(key: 'name', label: :name)
      expect(column.custom_sort?).to be false
    end
  end

  describe '#visible?' do
    it 'returns true when no condition' do
      column = described_class.new(key: 'name', label: :name)
      expect(column.visible?).to be true
    end

    it 'returns false when condition is false' do
      column = described_class.new(key: 'name', label: :name, condition: false)
      expect(column.visible?).to be false
    end

    it 'evaluates lambda condition with context' do
      context = Object.new
      column = described_class.new(key: 'name', label: :name, condition: -> { true })
      expect(column.visible?(context)).to be true
    end

    it 'evaluates condition in view context' do
      context = Object.new
      def context.admin?
        true
      end

      column = described_class.new(key: 'admin_only', label: :admin_only, condition: -> { admin? })
      expect(column.visible?(context)).to be true
    end
  end

  describe '#resolve_label' do
    it 'returns string label directly' do
      column = described_class.new(key: 'name', label: 'Custom Label')
      expect(column.resolve_label).to eq('Custom Label')
    end

    it 'translates dot-separated label as i18n key' do
      column = described_class.new(key: 'name', label: 'admin.products.name')
      expect(column.resolve_label).to be_a(String)
    end

    it 'translates symbol label' do
      column = described_class.new(key: 'name', label: :product_name)
      expect(column.resolve_label).to be_a(String)
    end

    it 'uses label for translation' do
      column = described_class.new(key: 'custom_field', label: :name)
      expect(column.resolve_label).to eq(Spree.t(:name))
    end
  end

  describe '#resolve_value' do
    let(:product) { build(:product, name: 'Test Product') }

    it 'calls method on record' do
      column = described_class.new(key: 'name', label: :name)
      expect(column.resolve_value(product)).to eq('Test Product')
    end

    it 'uses custom method' do
      column = described_class.new(key: 'display_name', label: :display_name, method: :name)
      expect(column.resolve_value(product)).to eq('Test Product')
    end

    it 'evaluates lambda method' do
      column = described_class.new(key: 'upper_name', label: :upper_name, method: ->(record) { record.name.upcase })
      expect(column.resolve_value(product)).to eq('TEST PRODUCT')
    end

    it 'evaluates lambda in view context' do
      context = Object.new
      def context.truncate(str, length:)
        str[0...length]
      end

      column = described_class.new(key: 'truncated', label: :truncated, method: ->(record) { truncate(record.name, length: 4) })
      expect(column.resolve_value(product, context)).to eq('Test')
    end
  end

  describe 'default_operators_for_type' do
    it 'returns string operators for string type' do
      column = described_class.new(key: 'name', label: :name, type: 'string')
      expect(column.operators).to include(:eq, :cont, :start, :end)
    end

    it 'returns number operators for number type' do
      column = described_class.new(key: 'quantity', label: :quantity, type: 'number')
      expect(column.operators).to include(:eq, :gt, :lt, :gteq, :lteq)
    end

    it 'returns date operators for date type' do
      column = described_class.new(key: 'created_at', label: :created_at, type: 'date')
      expect(column.operators).to include(:eq, :gt, :lt)
      expect(column.operators).not_to include(:cont)
    end

    it 'returns status operators for status type' do
      column = described_class.new(key: 'status', label: :status, type: 'status')
      expect(column.operators).to include(:eq, :not_eq, :in, :not_in)
    end

    it 'returns boolean operators for boolean type' do
      column = described_class.new(key: 'active', label: :active, type: 'boolean')
      expect(column.operators).to eq([:eq])
    end

    it 'returns autocomplete operators for autocomplete type' do
      column = described_class.new(key: 'taxon', label: :taxon, filter_type: 'autocomplete')
      expect(column.operators).to eq([:in, :not_in])
    end
  end

  describe '#attributes' do
    it 'returns hash representation' do
      column = described_class.new(
        key: 'name',
        label: 'Name',
        type: 'string',
        sortable: true,
        default: true,
        position: 10
      )

      attrs = column.attributes
      expect(attrs['key']).to eq('name')
      expect(attrs['label']).to eq('Name')
      expect(attrs['type']).to eq('string')
      expect(attrs['sortable']).to be true
      expect(attrs['default']).to be true
      expect(attrs['position']).to eq(10)
    end
  end

  describe '#deep_clone' do
    it 'creates a deep copy' do
      original = described_class.new(key: 'name', label: 'Original', default: true, position: 10)
      cloned = original.deep_clone

      cloned.label = 'Changed'

      expect(original.label).to eq('Original')
      expect(cloned.label).to eq('Changed')
      expect(cloned.key).to eq('name')
      expect(cloned.default).to be true
    end
  end
end
