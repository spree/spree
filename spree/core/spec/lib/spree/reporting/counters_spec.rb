require 'spec_helper'

RSpec.describe Spree::Reporting::Counters do
  let(:store) { @default_store }

  def evaluate(**options)
    described_class.new(store: store, **options).to_a.index_by(&:key)
  end

  it 'evaluates every registered counter, carrying its key and link but no copy' do
    results = evaluate

    expect(results.keys).to eq(
      %w[orders_to_fulfill payments_to_collect open_returns open_exchanges open_claims low_stock_items out_of_stock_items]
    )
    expect(results['out_of_stock_items'].link).to eq(
      'resource' => 'inventory',
      'filters' => [{ 'field' => 'stock_status', 'operator' => 'in', 'value' => 'out_of_stock' }]
    )
    expect(results['orders_to_fulfill'].nav).to eq('orders')
    expect(results['orders_to_fulfill'].link).to eq(
      'resource' => 'orders',
      'filters' => [{ 'field' => 'fulfillment_status', 'operator' => 'eq', 'value' => 'unfulfilled' }]
    )
    expect(results.values.map(&:value)).to all(be_a(Integer))
  end

  it 'keeps only the counters the caller may read' do
    results = evaluate(allowed: ->(counter) { counter.key_scope == 'read_stock' })

    expect(results.keys).to eq(%w[low_stock_items out_of_stock_items])
  end

  # The dashboard owns every string it shows, so a counter travels as a key
  # and a number — never as text the interface would have to render in
  # whatever locale the request happened to carry.
  it 'sends no copy for the client to have to override' do
    registry = Spree::Reporting::Registry.new
    registry.counter :flagged_orders, count: ->(_store, channel:) { 7 }

    result = described_class.new(store: store, registry: registry).to_a.first
    expect(result.key).to eq('flagged_orders')
    expect(result.value).to eq(7)
    expect(result).not_to respond_to(:label)
    expect(result).not_to respond_to(:description)
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

    it 'leaves money owed off the sidebar, where a near-permanent badge would stop informing' do
      expect(evaluate['payments_to_collect'].nav).to be_nil
    end
  end

  context 'with stock levels' do
    let!(:low_stock_product) { create(:product, store: store) }
    let!(:out_of_stock_product) { create(:product, store: store) }
    let(:low_stock_level) { low_stock_product.default_variant.stock_levels.first }

    before { low_stock_level.update!(count_on_hand: 3) }

    it 'counts what is running low and what has run out' do
      results = evaluate
      expect(results['low_stock_items'].value).to eq(1)
      expect(results['out_of_stock_items'].value).to eq(1)
    end

    # The Inventory page reads what a customer could still buy, so the counter
    # has to as well — otherwise the number and the list it opens disagree.
    it 'counts allocated stock as gone, the way the Inventory page does' do
      low_stock_level.update!(count_on_hand: 50, allocated_count: 50)

      results = evaluate
      expect(results['low_stock_items'].value).to eq(0)
      expect(results['out_of_stock_items'].value).to eq(2)
    end

    it 'reads the low stock threshold from the store' do
      stub_store_preferences(store, low_stock_threshold: 2)

      expect(evaluate['low_stock_items'].value).to eq(0)
    end

    it 'turns the low stock warning off at a threshold of zero' do
      stub_store_preferences(store, low_stock_threshold: 0)

      expect(evaluate['low_stock_items'].value).to eq(0)
    end

    it 'links each count to the Inventory page filtered to exactly those rows' do
      expect(evaluate['low_stock_items'].link).to eq(
        'resource' => 'inventory',
        'filters' => [{ 'field' => 'stock_status', 'operator' => 'in', 'value' => 'low_stock' }]
      )
    end

    # The filter the link carries and the counter must return the same rows.
    it 'agrees with the Inventory page filter it links to' do
      Spree::Current.store = store
      results = evaluate

      expect(Spree::StockLevel.for_store(store).with_stock_status('low_stock').count).
        to eq(results['low_stock_items'].value)
      expect(Spree::StockLevel.for_store(store).with_stock_status('out_of_stock').count).
        to eq(results['out_of_stock_items'].value)
    ensure
      Spree::Current.store = nil
    end
  end
end
