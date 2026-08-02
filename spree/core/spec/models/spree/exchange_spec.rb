require 'spec_helper'

RSpec.describe Spree::Exchange do
  let(:store) { @default_store }

  it 'generates a prefixed number and starts as requested' do
    exchange = create(:exchange, store: store)

    expect(exchange.number).to start_with('EX')
    expect(exchange).to be_requested
  end

  it 'is reachable from its order' do
    exchange = create(:exchange, store: store)

    expect(exchange.order.reload.exchanges).to include(exchange)
  end

  describe '#price_difference' do
    let(:exchange) { create(:exchange, store: store) }
    let(:line) { exchange.exchange_line_items.first }

    it 'is positive when the replacement costs more' do
      line.new_variant.prices.first.update!(amount: line.original_price + 25)

      expect(exchange.reload.price_difference).to be > 0
    end

    it 'is negative when the replacement costs less' do
      line.new_variant.prices.first.update!(amount: 0.01)

      expect(exchange.reload.price_difference).to be < 0
    end
  end

  describe Spree::ExchangeLineItem do
    let(:exchange) { create(:exchange, store: store) }
    let(:line) { exchange.exchange_line_items.first }

    # Swapping something for itself is a return, not an exchange.
    it 'rejects a replacement identical to the original' do
      line.new_variant = line.original_variant

      expect(line).not_to be_valid
      expect(line.errors[:new_variant]).to be_present
    end

    # Crediting the list price would over-refund a discounted line.
    it 'values the returned units at what the customer paid' do
      line_item = line.line_item

      expect(line.original_price).to eq(line_item.amount / line_item.quantity)
    end

    it 'starts with nothing received' do
      expect(line.received_quantity).to eq(0)
    end
  end
end
