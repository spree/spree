require 'spec_helper'

RSpec.describe Spree::Admin::Table::BulkAction do
  describe '#initialize' do
    it 'sets default values' do
      action = described_class.new(key: :delete)

      expect(action.key).to eq(:delete)
      expect(action.position).to eq(999)
      expect(action.method).to eq(:put)
      expect(action.label_options).to eq({})
    end

    it 'accepts custom options' do
      action = described_class.new(
        key: :export,
        label: 'Export Products',
        icon: 'download',
        modal_path: '/admin/exports/new',
        action_path: '/admin/exports',
        position: 10,
        method: :post
      )

      expect(action.label).to eq('Export Products')
      expect(action.icon).to eq('download')
      expect(action.modal_path).to eq('/admin/exports/new')
      expect(action.action_path).to eq('/admin/exports')
      expect(action.position).to eq(10)
      expect(action.method).to eq(:post)
    end

    it 'converts key to symbol' do
      action = described_class.new(key: 'delete')
      expect(action.key).to eq(:delete)
    end

    it 'converts method to symbol' do
      action = described_class.new(key: :delete, method: 'post')
      expect(action.method).to eq(:post)
    end

    it 'handles :if as alias for :condition' do
      condition = -> { true }
      action = described_class.new(key: :delete, if: condition)
      expect(action.condition).to eq(condition)
    end
  end

  describe 'validations' do
    it 'is invalid when key is missing' do
      action = described_class.new
      expect(action).not_to be_valid
      expect(action.errors[:key]).to include("can't be blank")
    end

    it 'is valid with just a key' do
      action = described_class.new(key: :delete)
      expect(action).to be_valid
    end

    it 'is invalid when method is not in allowed list' do
      action = described_class.new(key: :delete, method: :invalid)
      expect(action).not_to be_valid
      expect(action.errors[:method]).to include('is not included in the list')
    end

    it 'accepts all valid methods' do
      Spree::Admin::Table::BulkAction::METHODS.each do |method|
        action = described_class.new(key: :test, method: method)
        expect(action).to be_valid
      end
    end
  end

  describe '#visible?' do
    it 'returns true when no condition' do
      action = described_class.new(key: :delete)
      expect(action.visible?).to be true
    end

    it 'returns false when condition is false' do
      action = described_class.new(key: :delete, if: false)
      expect(action.visible?).to be false
    end

    it 'evaluates lambda condition with context' do
      context = Object.new
      action = described_class.new(key: :delete, if: -> { true })
      expect(action.visible?(context)).to be true
    end

    it 'evaluates condition in view context' do
      context = Object.new
      def context.can_delete?
        true
      end

      action = described_class.new(key: :delete, if: -> { can_delete? })
      expect(action.visible?(context)).to be true
    end

    it 'returns false when condition lambda returns false' do
      context = Object.new
      action = described_class.new(key: :delete, if: -> { false })
      expect(action.visible?(context)).to be false
    end
  end

  describe '#resolve_label' do
    it 'returns string label directly when not a translation key' do
      action = described_class.new(key: :delete, label: 'Delete Selected')
      expect(action.resolve_label).to eq('Delete Selected')
    end

    it 'translates admin translation key' do
      action = described_class.new(key: :delete, label: 'admin.bulk_ops.delete')
      # Will use Spree.t which falls back to humanized key if translation not found
      expect(action.resolve_label).to be_a(String)
    end

    it 'uses key as fallback' do
      action = described_class.new(key: :delete_selected)
      expect(action.resolve_label).to include('Delete')
    end

    it 'supports label_options' do
      action = described_class.new(key: :delete, label: :delete_count, label_options: { count: 5 })
      # Translation with options
      expect(action.resolve_label).to be_a(String)
    end
  end

  describe '#attributes' do
    it 'returns hash representation' do
      action = described_class.new(
        key: :delete,
        label: 'Delete',
        icon: 'trash',
        modal_path: '/modal',
        action_path: '/action',
        position: 10,
        confirm: 'Are you sure?',
        method: :delete
      )

      attrs = action.attributes
      expect(attrs['key']).to eq(:delete)
      expect(attrs['label']).to eq('Delete')
      expect(attrs['icon']).to eq('trash')
      expect(attrs['modal_path']).to eq('/modal')
      expect(attrs['action_path']).to eq('/action')
      expect(attrs['position']).to eq(10)
      expect(attrs['confirm']).to eq('Are you sure?')
      expect(attrs['method']).to eq(:delete)
    end
  end

  describe '#deep_clone' do
    it 'creates a deep copy' do
      original = described_class.new(key: :delete, label: 'Original', position: 10)
      cloned = original.deep_clone

      cloned.label = 'Changed'

      expect(original.label).to eq('Original')
      expect(cloned.label).to eq('Changed')
      expect(cloned.key).to eq(:delete)
      expect(cloned.position).to eq(10)
    end

    it 'preserves condition' do
      condition = -> { true }
      original = described_class.new(key: :delete, if: condition, label: 'Delete')
      cloned = original.deep_clone

      expect(cloned.condition).to eq(condition)
    end
  end

  describe '#confirm' do
    it 'returns nil when not set' do
      action = described_class.new(key: :delete)
      expect(action.confirm).to be_nil
    end

    it 'returns confirmation message when set' do
      action = described_class.new(key: :delete, confirm: 'Are you sure you want to delete?')
      expect(action.confirm).to eq('Are you sure you want to delete?')
    end
  end
end
