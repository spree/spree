require 'spec_helper'

# The two customization paths a merchant or developer actually asks for. If
# either of these breaks, the feature has not delivered what it promised.
RSpec.describe 'document number customization scenarios' do
  after { Spree.number_generators.clear }

  describe 'a merchant starting their sequence at a chosen number' do
    it 'issues the first order at the configured start' do
      stub_store_preferences(order_number_sequence_start: 10_001)

      expect(create(:order).number).to eq('R10001')
    end

    it 'counts up from there' do
      stub_store_preferences(order_number_sequence_start: 10_001)

      numbers = 3.times.map { create(:order).number }

      expect(numbers).to eq(%w[R10001 R10002 R10003])
    end

    it 'keeps counting when the start is raised afterwards' do
      stub_store_preferences(order_number_sequence_start: 10_001)
      create(:order)

      stub_store_preferences(order_number_sequence_start: 90_000)

      expect(create(:order).number).to eq('R10002')
    end

    it 'combines the start with a custom prefix and suffix' do
      stub_store_preferences(
        order_number_sequence_start: 5001,
        order_number_prefix: 'INV',
        order_number_suffix: '-EU'
      )

      expect(create(:order).number).to eq('INV5001-EU')
    end
  end

  describe 'a developer registering a custom generator' do
    let(:year_scoped_generator) do
      Class.new(Spree::NumberGenerators::Base) do
        def generate(record)
          sequence = Spree::NumberSequence.next_value(
            store: record.number_store,
            resource_type: record.number_key.to_s,
            start_at: 1
          )

          "#{prefix_for(record)}-2026-#{sequence.to_s.rjust(5, '0')}"
        end
      end
    end

    before { stub_const('MyApp::YearScopedNumbers', year_scoped_generator) }

    it 'produces numbers in the registered format' do
      Spree.number_generators[:order] = 'MyApp::YearScopedNumbers'

      expect(create(:order).number).to eq('R-2026-00001')
    end

    it 'honours the merchant prefix through prefix_for' do
      Spree.number_generators[:order] = 'MyApp::YearScopedNumbers'
      stub_store_preferences(order_number_prefix: 'ACME')

      expect(create(:order).number).to eq('ACME-2026-00001')
    end

    it 'overrides the store format switch' do
      Spree.number_generators[:order] = 'MyApp::YearScopedNumbers'
      stub_store_preferences(document_number_format: 'random')

      expect(create(:order).number).to eq('R-2026-00001')
    end

    it 'leaves other document types on the store default' do
      Spree.number_generators[:order] = 'MyApp::YearScopedNumbers'

      expect(create(:stock_transfer).number).to start_with('T')
    end

    it 'can be registered for several document types, each on its own counter' do
      Spree.number_generators[:order] = 'MyApp::YearScopedNumbers'
      Spree.number_generators[:stock_transfer] = 'MyApp::YearScopedNumbers'
      create(:order)

      # 00001, not 00002 — the transfer does not share the order counter.
      expect(create(:stock_transfer).number).to eq('T-2026-00001')
    end
  end

  describe 'the starting value is an order setting only' do
    it 'does not leak into other document types' do
      stub_store_preferences(order_number_sequence_start: 5001)

      expect(create(:order).number).to eq('R5001')
      expect(create(:stock_transfer).number).to eq('T1001')
    end
  end

  describe 'two stores with identical formats' do
    it 'jumps a new store past numbers the first store already owns' do
      5.times { create(:order) }                     # default store: R1001..R1005

      other_store = create(:store)
      order = create(:order, store: other_store)

      expect(order.number).to eq('R1006')
    end

    it 'continues the new store from its own counter afterwards' do
      3.times { create(:order) }                     # R1001..R1003

      other_store = create(:store)
      first = create(:order, store: other_store)     # jumps to R1004
      second = create(:order, store: other_store)

      expect([first.number, second.number]).to eq(%w[R1004 R1005])
    end
  end
end
