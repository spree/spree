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
      channel = described_class.new(store: store)
      expect(channel).not_to be_valid
      expect(channel.errors[:code]).to be_present
    end

    it 'derives code from name when blank' do
      channel = described_class.new(store: store, name: 'Point of Sale')
      channel.valid?
      expect(channel.code).to eq('point-of-sale')
    end

    it 'normalizes an explicit code' do
      channel = described_class.new(store: store, name: 'POS', code: 'My Channel!')
      channel.valid?
      expect(channel.code).to eq('my-channel')
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

  describe '#add_products' do
    let(:channel) { described_class.create!(store: store, name: 'POS', code: 'pos') }
    let(:product) { create(:product) }
    let(:other_product) { create(:product) }

    before { Spree::ProductPublication.where(channel: channel).delete_all }

    it 'publishes the listed products' do
      expect { channel.add_products([product.id, other_product.id]) }
        .to change { Spree::ProductPublication.where(channel: channel).count }.by(2)
    end

    it 'is idempotent — upserts on the [channel_id, product_id, store_id] unique index' do
      channel.add_products([product.id])

      expect { channel.add_products([product.id]) }
        .not_to change { Spree::ProductPublication.where(channel: channel, product: product).count }
    end

    it 'updates the publication window on re-publish' do
      channel.add_products([product.id])

      future = 1.day.from_now.change(usec: 0)
      channel.add_products([product.id], published_at: future)

      publication = Spree::ProductPublication.find_by(channel: channel, product: product)
      expect(publication.published_at).to be_within(1.second).of(future)
    end

    it 'is a no-op when product_ids is empty' do
      expect(channel.add_products([])).to eq(0)
    end

    it 'touches the channel' do
      channel.update_column(:updated_at, 1.day.ago)
      old_updated_at = channel.reload.updated_at

      Timecop.travel(1.second) do
        channel.add_products([product.id])
      end

      expect(channel.reload.updated_at).to be > old_updated_at
    end
  end

  describe '#remove_products' do
    let(:channel) { described_class.create!(store: store, name: 'POS', code: 'pos') }
    let(:product) { create(:product) }

    before { channel.add_products([product.id]) }

    it 'unpublishes the listed products' do
      expect { channel.remove_products([product.id]) }
        .to change { Spree::ProductPublication.where(channel: channel, product: product).count }.from(1).to(0)
    end

    it 'returns the number of publications destroyed' do
      expect(channel.remove_products([product.id])).to eq(1)
    end

    it 'is a no-op when product_ids is empty' do
      expect(channel.remove_products([])).to eq(0)
    end

    it 'touches the channel when something was unpublished' do
      channel.update_column(:updated_at, 1.day.ago)
      old_updated_at = channel.reload.updated_at

      Timecop.travel(1.second) do
        channel.remove_products([product.id])
      end

      expect(channel.reload.updated_at).to be > old_updated_at
    end

    it 'does not touch the channel when nothing was unpublished' do
      stray = create(:product)
      channel.update_column(:updated_at, 1.day.ago)
      old_updated_at = channel.reload.updated_at

      channel.remove_products([stray.id])

      expect(channel.reload.updated_at).to eq(old_updated_at)
    end
  end
end
