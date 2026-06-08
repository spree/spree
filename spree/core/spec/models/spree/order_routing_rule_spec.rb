require 'spec_helper'

RSpec.describe Spree::OrderRoutingRule, type: :model do
  let(:store) { @default_store }
  let(:channel) { store.default_channel }

  describe 'validations' do
    it 'requires a type' do
      rule = described_class.new(store: store, channel: channel, position: 1)
      expect(rule).not_to be_valid
      expect(rule.errors[:type]).to be_present
    end

    it 'requires a channel' do
      rule = Spree::OrderRouting::Rules::PreferredLocation.new(store: store, position: 1)
      expect(rule).not_to be_valid
      expect(rule.errors[:channel]).to be_present
    end

    it 'is valid when instantiated as an STI subclass with a channel' do
      rule = Spree::OrderRouting::Rules::PreferredLocation.new(store: store, channel: channel, position: 1)
      expect(rule).to be_valid
    end

    it 'rejects rules whose channel belongs to a different store' do
      foreign_channel = create(:store).default_channel
      rule = Spree::OrderRouting::Rules::PreferredLocation.new(
        store: store, channel: foreign_channel, position: 1
      )

      expect(rule).not_to be_valid
      expect(rule.errors[:channel]).to include(Spree.t('errors.messages.channel_store_mismatch'))
    end

    it 'rejects a present-but-unregistered STI type' do
      rule = Spree::OrderRouting::Rules::PreferredLocation.new(store: store, channel: channel, position: 1)
      rule.type = 'Spree::OrderRoutingRule'
      expect(rule).not_to be_valid
      expect(rule.errors[:type]).to be_present
    end
  end

  describe 'Spree.order_routing.rules' do
    it 'includes the core rule kinds' do
      expect(Spree.order_routing.rules).to include(
        Spree::OrderRouting::Rules::PreferredLocation,
        Spree::OrderRouting::Rules::MinimizeSplits,
        Spree::OrderRouting::Rules::DefaultLocation
      )
    end
  end

  describe 'scopes' do
    # Channels seed 3 default rules on create. We test scopes against fresh rules
    # in a clean channel to avoid coupling to the seed list.
    let(:fresh_channel) { create(:store).default_channel.tap { |c| c.order_routing_rules.destroy_all } }
    let(:fresh_store) { fresh_channel.store }
    let!(:active_rule) do
      Spree::OrderRouting::Rules::PreferredLocation.create!(
        store: fresh_store, channel: fresh_channel, position: 1, active: true
      )
    end
    let!(:inactive_rule) do
      Spree::OrderRouting::Rules::MinimizeSplits.create!(
        store: fresh_store, channel: fresh_channel, position: 2, active: false
      )
    end

    it 'filters by active' do
      expect(described_class.for_channel(fresh_channel).active).to contain_exactly(active_rule)
    end

    it 'orders by position' do
      expect(described_class.for_channel(fresh_channel).ordered.map(&:type))
        .to eq(%w[Spree::OrderRouting::Rules::PreferredLocation Spree::OrderRouting::Rules::MinimizeSplits])
    end

    it 'for_channel returns rules belonging to that channel only' do
      other_channel = fresh_store.channels.create!(name: 'POS', code: 'pos')
      # Both channels seed 3 default rules each; we just verify the scope partitions them.
      expect(described_class.for_channel(fresh_channel)).to contain_exactly(active_rule, inactive_rule)
      expect(described_class.for_channel(other_channel).count).to eq(3)
      expect(described_class.for_channel(other_channel).pluck(:channel_id)).to all(eq(other_channel.id))
    end
  end

  describe '#rank' do
    let(:order) { build(:order, store: store) }
    let(:locations) { [create(:stock_location)] }

    it 'is implemented by subclasses' do
      rule = Spree::OrderRouting::Rules::DefaultLocation.create!(store: store, channel: channel, position: 99)
      rankings = rule.rank(order, locations)
      expect(rankings).to all(be_a(Spree::OrderRoutingRule::LocationRanking))
    end

    it 'raises NotImplementedError on the base class' do
      rule = described_class.new(store: store, channel: channel, position: 99)
      expect { rule.rank(order, locations) }.to raise_error(NotImplementedError)
    end
  end
end
