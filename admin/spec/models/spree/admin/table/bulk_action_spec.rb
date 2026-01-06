require 'spec_helper'

RSpec.describe Spree::Admin::Table::BulkAction do
  describe '#initialize' do
    it 'sets default values' do
      action = described_class.new(:delete)

      expect(action.key).to eq(:delete)
      expect(action.position).to eq(999)
      expect(action.method).to eq(:put)
    end

    it 'accepts custom options' do
      action = described_class.new(:export,
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
      action = described_class.new('delete')
      expect(action.key).to eq(:delete)
    end
  end

  describe '#visible?' do
    it 'returns true when no condition' do
      action = described_class.new(:delete)
      expect(action.visible?).to be true
    end

    it 'returns false when condition is false' do
      action = described_class.new(:delete, if: false)
      expect(action.visible?).to be false
    end

    it 'evaluates lambda condition with context' do
      context = Object.new
      action = described_class.new(:delete, if: -> { true })
      expect(action.visible?(context)).to be true
    end

    it 'evaluates condition in view context' do
      context = Object.new
      def context.can_delete?
        true
      end

      action = described_class.new(:delete, if: -> { can_delete? })
      expect(action.visible?(context)).to be true
    end

    it 'returns false when condition lambda returns false' do
      context = Object.new
      action = described_class.new(:delete, if: -> { false })
      expect(action.visible?(context)).to be false
    end
  end

  describe '#resolve_label' do
    it 'returns string label directly when not a translation key' do
      action = described_class.new(:delete, label: 'Delete Selected')
      expect(action.resolve_label).to eq('Delete Selected')
    end

    it 'translates admin translation key' do
      action = described_class.new(:delete, label: 'admin.bulk_ops.delete')
      # Will use Spree.t which falls back to humanized key if translation not found
      expect(action.resolve_label).to be_a(String)
    end

    it 'uses key as fallback' do
      action = described_class.new(:delete_selected)
      expect(action.resolve_label).to include('Delete')
    end

    it 'supports label_options' do
      action = described_class.new(:delete, label: :delete_count, label_options: { count: 5 })
      # Translation with options
      expect(action.resolve_label).to be_a(String)
    end
  end

  describe '#to_h' do
    it 'returns hash representation' do
      action = described_class.new(:delete,
        label: 'Delete',
        icon: 'trash',
        modal_path: '/modal',
        action_path: '/action',
        position: 10,
        confirm: 'Are you sure?',
        method: :delete
      )

      hash = action.to_h

      expect(hash[:key]).to eq(:delete)
      expect(hash[:label]).to eq('Delete')
      expect(hash[:icon]).to eq('trash')
      expect(hash[:modal_path]).to eq('/modal')
      expect(hash[:action_path]).to eq('/action')
      expect(hash[:position]).to eq(10)
      expect(hash[:confirm]).to eq('Are you sure?')
      expect(hash[:method]).to eq(:delete)
    end
  end

  describe '#deep_clone' do
    it 'creates a deep copy' do
      original = described_class.new(:delete, label: 'Original', position: 10)
      cloned = original.deep_clone

      cloned.label = 'Changed'

      expect(original.label).to eq('Original')
      expect(cloned.label).to eq('Changed')
      expect(cloned.key).to eq(:delete)
      expect(cloned.position).to eq(10)
    end

    it 'preserves condition' do
      condition = -> { true }
      original = described_class.new(:delete, if: condition, label: 'Delete')
      cloned = original.deep_clone

      expect(cloned.condition).to eq(condition)
    end
  end

  describe '#confirm' do
    it 'returns nil when not set' do
      action = described_class.new(:delete)
      expect(action.confirm).to be_nil
    end

    it 'returns confirmation message when set' do
      action = described_class.new(:delete, confirm: 'Are you sure you want to delete?')
      expect(action.confirm).to eq('Are you sure you want to delete?')
    end
  end
end
