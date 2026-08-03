require 'spec_helper'

RSpec.describe 'Spree::Exchanges workflows' do
  let(:store) { @default_store }
  let(:order) { create(:shipped_order, store: store, line_items_count: 2) }
  let(:fulfillment_item) { order.fulfillment_items.first }
  let(:replacement) { create(:variant, product: fulfillment_item.variant.product) }

  before { Spree.hooks.clear! }
  after { Spree.hooks.clear! }

  def create_exchange(**overrides)
    Spree::Exchanges::Create.call(
      order: order,
      items: [{ fulfillment_item: fulfillment_item, new_variant: replacement, quantity: 1 }],
      **overrides
    )
  end

  describe Spree::Exchanges::Create do
    it 'opens a requested exchange' do
      result = create_exchange

      expect(result).to be_success
      expect(result.value).to be_requested
      expect(result.value.exchange_line_items.count).to eq(1)
    end

    it 'refuses a replacement that cannot be sold' do
      allow_any_instance_of(Spree::Variant).to receive(:purchasable?).and_return(false)

      expect(create_exchange).to be_failure
    end

    it 'refuses an order that was never completed' do
      cart_order = create(:order, store: store)

      expect(Spree::Exchanges::Create.call(order: cart_order, items: [])).to be_failure
    end

    it 'lets a validate handler veto' do
      Spree.hooks.register('exchanges.create.validate') { |flow| flow.reject!('no exchanges') }

      result = create_exchange

      expect(result).to be_failure
      expect(order.reload.exchanges).to be_empty
    end
  end

  describe Spree::Exchanges::Approve do
    it 'approves a requested exchange' do
      exchange = create_exchange.value

      result = Spree::Exchanges::Approve.call(exchange: exchange)

      expect(result).to be_success
      expect(result.value).to be_approved
    end
  end

  describe Spree::Exchanges::Receive do
    let(:exchange) { create(:approved_exchange, store: store) }

    it 'receives and restocks the returned variant' do
      line = exchange.exchange_line_items.first
      stock_item = exchange.stock_location.stock_item_or_create(line.original_variant)

      expect { Spree::Exchanges::Receive.call(exchange: exchange) }.
        to change { stock_item.reload.count_on_hand }.by(line.quantity)

      expect(exchange.reload).to be_received
    end

    it 'does not restock what came back damaged' do
      line = exchange.exchange_line_items.first
      stock_item = exchange.stock_location.stock_item_or_create(line.original_variant)

      Spree::Exchanges::Receive.call(
        exchange: exchange,
        items: [{ exchange_line_item: line, quantity: 1, resellable: false }]
      )

      expect(stock_item.reload.count_on_hand).to eq(stock_item.count_on_hand)
      expect(line.reload.resellable).to be(false)
    end
  end

  describe Spree::Exchanges::Fulfill do
    let(:exchange) { create(:received_exchange, store: store) }

    it 'refuses an exchange that has not been received' do
      approved = create(:approved_exchange, store: store)

      expect(Spree::Exchanges::Fulfill.call(exchange: approved)).to be_failure
    end

    it 'creates a replacement fulfillment and marks it fulfilled' do
      exchange.exchange_line_items.each do |line|
        line.new_variant.stock_items.first&.set_count_on_hand(10)
      end

      result = Spree::Exchanges::Fulfill.call(exchange: exchange)

      expect(result).to be_success
      expect(result.value).to be_fulfilled
    end
  end

  describe Spree::Exchanges::Cancel do
    it 'cancels before the goods arrive' do
      exchange = create_exchange.value

      expect(Spree::Exchanges::Cancel.call(exchange: exchange).value).to be_canceled
    end

    it 'refuses once received' do
      received = create(:received_exchange, store: store)

      expect(Spree::Exchanges::Cancel.call(exchange: received)).to be_failure
    end
  end
end
