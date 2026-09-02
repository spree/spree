require 'spec_helper'

RSpec.describe 'Spree::Order withdrawal period' do
  let(:store) { @default_store }
  let(:market) { store.default_market }
  let(:order) { create(:completed_order_with_totals, store: store) }

  before { order.update_columns(market_id: market.id, completed_at: 10.days.ago) }

  describe 'before anything is delivered' do
    # The statutory clock starts on physical possession. Counting from
    # completion would expire the deadline before the period had begun, telling
    # a buyer their right had run out while they waited for the goods.
    it 'reports no deadline yet' do
      expect(order.withdrawal_period_ends_at).to be_nil
    end

    it 'still treats the buyer as within their rights' do
      expect(order).to be_within_withdrawal_period
    end
  end

  describe 'once delivered' do
    let(:delivered_at) { 2.days.ago }

    before do
      fulfillment = order.fulfillments.first || create(:fulfillment, order: order)
      fulfillment.update_columns(delivered_at: delivered_at, status: 'delivered')
      order.reload
    end

    it 'counts from the day the buyer received the goods' do
      expect(order.withdrawal_period_ends_at).to be_within(1.minute).of(delivered_at + 14.days)
    end

    it 'is still open' do
      expect(order).to be_within_withdrawal_period
    end
  end

  describe 'with a split shipment' do
    it 'has not started while one parcel is still in transit' do
      first = order.fulfillments.first || create(:fulfillment, order: order)
      first.update_columns(delivered_at: 9.days.ago, status: 'delivered')
      create(:fulfillment, order: order)
      order.reload

      # For goods delivered separately the period runs from the last one, so
      # neither a start nor an end can be named while one is outstanding.
      expect(order.withdrawal_period_starts_at).to be_nil
      expect(order.withdrawal_period_ends_at).to be_nil
      expect(order).to be_within_withdrawal_period
    end

    it 'waits for the final parcel' do
      first = order.fulfillments.first || create(:fulfillment, order: order)
      first.update_columns(delivered_at: 9.days.ago, status: 'delivered')
      last = create(:fulfillment, order: order)
      last.update_columns(delivered_at: 1.day.ago, status: 'delivered')
      order.reload

      expect(order.withdrawal_period_ends_at).to be_within(1.minute).of(1.day.ago + 14.days)
    end
  end

  describe 'when the market grants no withdrawal right' do
    # Stubbed rather than persisted: a market row whose preferences column is
    # NULL cannot store a nil override — the getter falls back to the declared
    # default. That is pre-existing behaviour shared with
    # `return_window_days`, so this asserts the reading, not the writing.
    before { allow(market).to receive(:preferred_withdrawal_period_days).and_return(nil) }

    it 'reports no deadline' do
      allow(order).to receive(:market).and_return(market)

      expect(order.withdrawal_period_ends_at).to be_nil
      expect(order).not_to be_within_withdrawal_period
    end
  end

  describe 'an order that is not complete' do
    let(:cart) { create(:order, store: store) }

    it 'has no deadline yet' do
      expect(cart.withdrawal_period_ends_at).to be_nil
    end
  end

  it 'is separate from the return window' do
    market.update!(preferred_return_window_days: 30, preferred_withdrawal_period_days: 14)

    expect(order.reload.withdrawal_period_days).to eq(14)
    expect(market.preferred_return_window_days).to eq(30)
  end

  describe 'once the period has passed' do
    before do
      fulfillment = order.fulfillments.first || create(:fulfillment, order: order)
      fulfillment.update_columns(delivered_at: 30.days.ago, status: 'delivered')
      order.reload
    end

    it 'is closed' do
      expect(order).not_to be_within_withdrawal_period
    end
  end
end
