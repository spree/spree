require 'spec_helper'

RSpec.describe Spree::Reporting::Registry do
  subject(:registry) { described_class.new }

  describe '#metric' do
    it 'registers and fetches metrics' do
      registry.metric :margin, sql: 'SUM(x)', base: :orders, format: :money
      expect(registry.metric!(:margin).sql).to eq('SUM(x)')
      expect(registry.metric!('margin').money?).to be true
    end

    it 'raises on duplicate registration unless replace: true' do
      registry.metric :margin, sql: 'SUM(x)', base: :orders
      expect { registry.metric :margin, sql: 'SUM(y)', base: :orders }.to raise_error(ArgumentError, /already registered/)

      registry.metric :margin, sql: 'SUM(y)', base: :orders, replace: true
      expect(registry.metric!(:margin).sql).to eq('SUM(y)')
    end
  end

  describe '#dimension' do
    it 'registers value dimensions by default' do
      registry.dimension :warehouse, base: :orders, column: :stock_location_id
      expect(registry.dimension!(:warehouse).time?).to be false
    end

    it 'requires a key_scope whenever a subject is declared' do
      expect do
        registry.dimension :vendor, base: :orders, column: :vendor_id, subject: -> { Spree::Order }
      end.to raise_error(ArgumentError, /key_scope/)
    end
  end

  describe 'unknown members' do
    it 'raises UnknownMember naming the valid options' do
      registry.metric :margin, sql: 'SUM(x)', base: :orders

      expect { registry.metric!(:nope) }.to raise_error(Spree::Reporting::UnknownMember, /margin/)
      expect { registry.dimension!(:nope) }.to raise_error(Spree::Reporting::UnknownMember)
    end
  end

  describe 'core starter vocabulary' do
    it 'is registered on Spree.reporting' do
      expect(Spree.reporting.metric!(:net_sales).base).to eq(:line_items)
      expect(Spree.reporting.metric!(:average_order_value).derived?).to be true
      expect(Spree.reporting.dimension!(:completed_at).grains).to include(:day)
      expect(Spree.reporting.dimension!(:product).lookup).to eq(:product)
    end
  end

  describe 'bases' do
    it 'registers a base with the shape the how-to guide documents' do
      registry = described_class.new
      registry.base :subscriptions, family: :subscriptions, table: '%{subscriptions}',
                    time_column: '%{subscriptions}.created_at',
                    relation: ->(store, range, _currency) { store.orders.where(created_at: range) }

      base = registry.base!(:subscriptions)
      expect(base.family).to eq(:subscriptions)
      # A base reaches only itself unless it says otherwise.
      expect(base.reaches?(:subscriptions)).to be true
      expect(base.reaches?(:orders)).to be false
    end

    it 'groups core bases into the three families that never mix' do
      families = Spree.reporting.bases.values.group_by(&:family).transform_values { |b| b.map(&:name).sort }

      expect(families[:sales]).to eq(%i[line_items orders])
      expect(families[:payments]).to eq(%i[payments])
      expect(families[:inventory]).to eq(%i[stock_movements])
    end

    it 'reads a line item axis from line items, never from the order its clock lives on' do
      # The two were conflated while bases were hardcoded, which silently read
      # every line-item dimension off spree_orders.
      line_items = Spree.reporting.base!(:line_items)
      expect(line_items.table).to include('line_items')
      expect(line_items.time_column).to include('orders')
    end
  end
end
