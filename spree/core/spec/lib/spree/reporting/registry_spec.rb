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
  end

  describe 'unknown members' do
    it 'raises UnknownMember naming the valid options' do
      registry.metric :margin, sql: 'SUM(x)', base: :orders

      expect { registry.metric!(:nope) }.to raise_error(Spree::Reporting::UnknownMember, /margin/)
      expect { registry.dimension!(:nope) }.to raise_error(Spree::Reporting::UnknownMember)
    end
  end

  describe '#schema' do
    it 'serializes registered members for introspection' do
      registry.metric :margin, sql: 'SUM(x)', base: :orders, format: :money
      registry.dimension :day, base: :orders, column: :completed_at, type: :time, grains: %i[day]

      expect(registry.schema[:metrics]).to contain_exactly({ name: :margin, format: :money, derived: false })
      expect(registry.schema[:dimensions]).to contain_exactly({ name: :day, type: :time, grains: %i[day] })
    end
  end

  describe 'core starter vocabulary' do
    it 'is registered on Spree.reporting' do
      expect(Spree.reporting.metric!(:net_revenue).base).to eq(:line_items)
      expect(Spree.reporting.metric!(:aov).derived?).to be true
      expect(Spree.reporting.dimension!(:completed_at).grains).to include(:day)
      expect(Spree.reporting.dimension!(:product).lookup).to eq(:product)
    end
  end
end
