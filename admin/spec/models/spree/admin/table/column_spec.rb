require 'spec_helper'

RSpec.describe Spree::Admin::Table::Column do
  describe '#initialize' do
    it 'sets default values' do
      column = described_class.new(:name)

      expect(column.key).to eq(:name)
      expect(column.type).to eq(:string)
      expect(column.filter_type).to eq(:string)
      expect(column.sortable).to be true
      expect(column.filterable).to be true
      expect(column.displayable).to be true
      expect(column.default).to be false
      expect(column.align).to eq(:left)
      expect(column.ransack_attribute).to eq('name')
    end

    it 'accepts custom options' do
      column = described_class.new(:price,
        label: 'Product Price',
        type: :currency,
        sortable: false,
        filterable: true,
        default: true,
        position: 10,
        align: :right,
        ransack_attribute: 'master_price'
      )

      expect(column.label).to eq('Product Price')
      expect(column.type).to eq(:currency)
      expect(column.filter_type).to eq(:currency)
      expect(column.sortable).to be false
      expect(column.default).to be true
      expect(column.position).to eq(10)
      expect(column.align).to eq(:right)
      expect(column.ransack_attribute).to eq('master_price')
    end

    it 'uses type as filter_type by default' do
      column = described_class.new(:status, type: :status)

      expect(column.filter_type).to eq(:status)
    end

    it 'allows different filter_type than type' do
      column = described_class.new(:status, type: :custom, filter_type: :select)

      expect(column.type).to eq(:custom)
      expect(column.filter_type).to eq(:select)
    end
  end

  describe '#sortable?' do
    it 'returns true when sortable' do
      column = described_class.new(:name, sortable: true)
      expect(column.sortable?).to be true
    end

    it 'returns false when not sortable' do
      column = described_class.new(:name, sortable: false)
      expect(column.sortable?).to be false
    end
  end

  describe '#filterable?' do
    it 'returns true when filterable' do
      column = described_class.new(:name, filterable: true)
      expect(column.filterable?).to be true
    end

    it 'returns false when not filterable' do
      column = described_class.new(:name, filterable: false)
      expect(column.filterable?).to be false
    end
  end

  describe '#default?' do
    it 'returns true when default' do
      column = described_class.new(:name, default: true)
      expect(column.default?).to be true
    end

    it 'returns false when not default' do
      column = described_class.new(:name, default: false)
      expect(column.default?).to be false
    end
  end

  describe '#custom_sort?' do
    it 'returns true when sort_scope_asc is present' do
      column = described_class.new(:price, sort_scope_asc: :ascend_by_price)
      expect(column.custom_sort?).to be true
    end

    it 'returns true when sort_scope_desc is present' do
      column = described_class.new(:price, sort_scope_desc: :descend_by_price)
      expect(column.custom_sort?).to be true
    end

    it 'returns false when no sort scopes' do
      column = described_class.new(:name)
      expect(column.custom_sort?).to be false
    end
  end

  describe '#visible?' do
    it 'returns true when no condition' do
      column = described_class.new(:name)
      expect(column.visible?).to be true
    end

    it 'returns false when condition is false' do
      column = described_class.new(:name, if: false)
      expect(column.visible?).to be false
    end

    it 'evaluates lambda condition with context' do
      context = Object.new
      column = described_class.new(:name, if: -> { true })
      expect(column.visible?(context)).to be true
    end

    it 'evaluates condition in view context' do
      context = Object.new
      def context.admin?
        true
      end

      column = described_class.new(:admin_only, if: -> { admin? })
      expect(column.visible?(context)).to be true
    end
  end

  describe '#resolve_label' do
    it 'returns string label directly' do
      column = described_class.new(:name, label: 'Custom Label')
      expect(column.resolve_label).to eq('Custom Label')
    end

    it 'translates symbol label' do
      column = described_class.new(:name, label: :product_name)
      # Uses Spree.t which will return the translated value or humanized key
      expect(column.resolve_label).to be_a(String)
    end

    it 'uses key as fallback' do
      column = described_class.new(:custom_field)
      expect(column.resolve_label).to include('Custom')
    end
  end

  describe '#resolve_value' do
    let(:product) { build(:product, name: 'Test Product') }

    it 'calls method on record' do
      column = described_class.new(:name)
      expect(column.resolve_value(product)).to eq('Test Product')
    end

    it 'uses custom method' do
      column = described_class.new(:display_name, method: :name)
      expect(column.resolve_value(product)).to eq('Test Product')
    end

    it 'evaluates lambda method' do
      column = described_class.new(:upper_name, method: ->(record) { record.name.upcase })
      expect(column.resolve_value(product)).to eq('TEST PRODUCT')
    end

    it 'evaluates lambda in view context' do
      context = Object.new
      def context.truncate(str, length:)
        str[0...length]
      end

      column = described_class.new(:truncated, method: ->(record) { truncate(record.name, length: 4) })
      expect(column.resolve_value(product, context)).to eq('Test')
    end
  end

  describe '#default_operators_for_type' do
    it 'returns string operators for string type' do
      column = described_class.new(:name, type: :string)
      expect(column.operators).to include(:eq, :cont, :start, :end)
    end

    it 'returns number operators for number type' do
      column = described_class.new(:quantity, type: :number)
      expect(column.operators).to include(:eq, :gt, :lt, :gteq, :lteq)
    end

    it 'returns date operators for date type' do
      column = described_class.new(:created_at, type: :date)
      expect(column.operators).to include(:eq, :gt, :lt)
      expect(column.operators).not_to include(:cont)
    end

    it 'returns status operators for status type' do
      column = described_class.new(:status, type: :status)
      expect(column.operators).to include(:eq, :not_eq, :in, :not_in)
    end

    it 'returns boolean operators for boolean type' do
      column = described_class.new(:active, type: :boolean)
      expect(column.operators).to eq([:eq])
    end

    it 'returns autocomplete operators for autocomplete type' do
      column = described_class.new(:taxon, filter_type: :autocomplete)
      expect(column.operators).to eq([:in, :not_in])
    end
  end

  describe '#to_h' do
    it 'returns hash representation' do
      column = described_class.new(:name,
        label: 'Name',
        type: :string,
        sortable: true,
        default: true,
        position: 10
      )

      hash = column.to_h
      expect(hash[:key]).to eq(:name)
      expect(hash[:label]).to eq('Name')
      expect(hash[:type]).to eq(:string)
      expect(hash[:sortable]).to be true
      expect(hash[:default]).to be true
      expect(hash[:position]).to eq(10)
    end
  end

  describe '#deep_clone' do
    it 'creates a deep copy' do
      original = described_class.new(:name, label: 'Original', default: true, position: 10)
      cloned = original.deep_clone

      cloned.label = 'Changed'

      expect(original.label).to eq('Original')
      expect(cloned.label).to eq('Changed')
      expect(cloned.key).to eq(:name)
      expect(cloned.default).to be true
    end
  end
end
