require 'spec_helper'

RSpec.describe Spree::Channel, type: :model do
  let(:store) { @default_store }

  describe 'validations' do
    it 'requires name' do
      channel = described_class.new(store: store, code: 'pos')
      expect(channel).not_to be_valid
      expect(channel.errors[:name]).to be_present
    end

    it 'requires code' do
      channel = described_class.new(store: store, name: 'POS')
      expect(channel).not_to be_valid
      expect(channel.errors[:code]).to be_present
    end

    it 'requires code unique within a store' do
      described_class.create!(store: store, name: 'POS', code: 'pos')
      duplicate = described_class.new(store: store, name: 'POS 2', code: 'pos')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:code]).to be_present
    end

    it 'allows the same code across different stores' do
      described_class.create!(store: store, name: 'POS', code: 'pos')
      other_store = create(:store)
      # Auto-seeded 'online' channel is fine; we test the same arbitrary code.
      cross = described_class.new(store: other_store, name: 'POS', code: 'pos')

      expect(cross).to be_valid
    end
  end

  describe 'defaults' do
    it 'is active by default' do
      expect(described_class.new(store: store).active).to be true
    end
  end

  describe '.active scope' do
    it 'filters active channels only' do
      fresh_store = create(:store).tap { |s| s.channels.destroy_all }
      active = described_class.create!(store: fresh_store, name: 'A', code: 'a', active: true)
      described_class.create!(store: fresh_store, name: 'B', code: 'b', active: false)

      expect(fresh_store.channels.active).to contain_exactly(active)
    end
  end

  describe 'preferences' do
    it 'falls back to nil order_routing_strategy by default' do
      channel = described_class.new(store: store, name: 'POS', code: 'pos')
      expect(channel.preferred_order_routing_strategy).to be_nil
    end

    it 'persists a custom routing strategy override' do
      channel = described_class.create!(
        store: store, name: 'POS', code: 'pos',
        preferred_order_routing_strategy: 'CustomStrategy'
      )
      expect(channel.reload.preferred_order_routing_strategy).to eq('CustomStrategy')
    end
  end

  describe 'prefixed_id' do
    it 'starts with ch_' do
      channel = described_class.create!(store: store, name: 'POS', code: 'pos')
      expect(channel.prefixed_id).to start_with('ch_')
    end
  end

  describe '#ensure_default_order_routing_rules' do
    it 'creates the three built-in rules in priority order on create' do
      expect { described_class.create!(store: store, name: 'POS', code: 'pos') }
        .to change(Spree::OrderRoutingRule, :count).by(3)

      rules = described_class.find_by(code: 'pos').order_routing_rules.ordered
      expect(rules.map(&:class)).to eq([
        Spree::OrderRouting::Rules::PreferredLocation,
        Spree::OrderRouting::Rules::MinimizeSplits,
        Spree::OrderRouting::Rules::DefaultLocation
      ])
      expect(rules.map(&:position)).to eq([1, 2, 3])
    end

    it 'is idempotent — re-invoking does not create duplicates' do
      channel = described_class.create!(store: store, name: 'POS', code: 'pos')
      expect { channel.send(:ensure_default_order_routing_rules) }
        .not_to change(Spree::OrderRoutingRule, :count)
    end
  end
end
