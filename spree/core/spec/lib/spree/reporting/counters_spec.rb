require 'spec_helper'

RSpec.describe Spree::Reporting::Counters do
  let(:store) { @default_store }

  def evaluate(**options)
    described_class.new(store: store, **options).to_a.index_by(&:key)
  end

  it 'evaluates every registered counter with a localized label and its link' do
    results = evaluate

    expect(results.keys).to eq(
      %w[orders_to_fulfill payments_to_collect open_returns open_exchanges open_claims low_stock_items out_of_stock_items]
    )
    expect(results['orders_to_fulfill'].label).to eq('Orders to fulfill')
    expect(results['orders_to_fulfill'].nav).to be_nil
    expect(results['orders_to_fulfill'].link).to eq(
      'resource' => 'orders',
      'filters' => [{ 'field' => 'fulfillment_status', 'operator' => 'eq', 'value' => 'unfulfilled' }]
    )
    expect(results['out_of_stock_items'].link).to be_nil
    expect(results.values.map(&:value)).to all(be_a(Integer))
  end

  it 'keeps only the counters the caller may read' do
    results = evaluate(allowed: ->(counter) { counter.key_scope == 'read_stock' })

    expect(results.keys).to eq(%w[low_stock_items out_of_stock_items])
  end

  it 'humanizes the name of a counter with no locale entry' do
    registry = Spree::Reporting::Registry.new
    registry.counter :flagged_orders, count: ->(_store, channel:) { 7 }

    result = described_class.new(store: store, registry: registry).to_a.first
    expect(result.label).to eq('Flagged orders')
    expect(result.description).to be_nil
    expect(result.value).to eq(7)
  end

  context 'with orders' do
    let!(:ready_order) { create(:order_ready_to_ship, store: store) }
    let!(:balance_due_order) do
      create(:completed_order_with_totals, store: store, payment_status: 'authorized', fulfillment_status: 'fulfilled')
    end

    it 'counts orders to fulfill and payments to collect' do
      results = evaluate
      expect(results['orders_to_fulfill'].value).to eq(1)
      expect(results['payments_to_collect'].value).to eq(1)
    end

    it 'narrows order counts to a channel' do
      channel = create(:channel, store: store)
      create(:order_ready_to_ship, store: store, channel: channel)

      results = evaluate(channel: channel)
      expect(results['orders_to_fulfill'].value).to eq(1)
      expect(results['payments_to_collect'].value).to eq(0)
    end
  end

  context 'with post-sale records' do
    let!(:open_return) { create(:return) }

    it 'counts everything still in flight, and names the nav entry it badges' do
      result = evaluate['open_returns']

      expect(result.value).to eq(1)
      expect(result.nav).to eq('returns')
    end

    it 'counts a received return, which still needs refunding' do
      open_return.update!(status: 'received')

      expect(evaluate['open_returns'].value).to eq(1)
    end

    it 'ignores a refunded return' do
      open_return.update!(status: 'refunded')

      expect(evaluate['open_returns'].value).to eq(0)
    end

    it 'counts exchanges and claims on their own nav entries' do
      expect(evaluate['open_exchanges'].nav).to eq('exchanges')
      expect(evaluate['open_claims'].nav).to eq('claims')
    end
  end

  context 'with stock levels' do
    let!(:low_stock_product) { create(:product, store: store) }
    let!(:out_of_stock_product) { create(:product, store: store) }

    before { low_stock_product.default_variant.stock_levels.first.update!(count_on_hand: 3) }

    it 'counts low stock and out of stock variants' do
      results = evaluate
      expect(results['low_stock_items'].value).to eq(1)
      expect(results['out_of_stock_items'].value).to eq(1)
    end

    it 'reads the low stock threshold from the store and says so in the description' do
      stub_store_preferences(store, low_stock_threshold: 2)

      result = evaluate['low_stock_items']
      expect(result.value).to eq(0)
      expect(result.description).to eq('2 units or fewer on hand at an active location.')
    end

    it 'turns the low stock warning off at a threshold of zero' do
      stub_store_preferences(store, low_stock_threshold: 0)

      result = evaluate['low_stock_items']
      expect(result.value).to eq(0)
      expect(result.description).to start_with('Turned off')
    end

    it 'ignores variants that do not track inventory' do
      low_stock_product.default_variant.update!(track_inventory: false)
      out_of_stock_product.default_variant.update!(track_inventory: false)

      results = evaluate
      expect(results['low_stock_items'].value).to eq(0)
      expect(results['out_of_stock_items'].value).to eq(0)
    end
  end
end
