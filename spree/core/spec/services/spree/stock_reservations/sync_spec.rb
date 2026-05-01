require 'spec_helper'

describe Spree::StockReservations::Sync do
  let(:order) { create(:order_with_line_items, line_items_count: 1) }
  let(:variant) { order.line_items.first.variant }
  let!(:stock_item) do
    si = variant.stock_items.first
    si.update!(backorderable: false)
    si.set_count_on_hand(10)
    si
  end

  before { Spree::Config[:stock_reservations_enabled] = true }

  context 'when entering checkout (was_in_cart && !cart?)' do
    before { order.update_column(:state, 'address') }

    it 'creates a reservation' do
      expect { described_class.call(order: order, was_in_cart: true) }
        .to change { Spree::StockReservation.where(order_id: order.id).count }.from(0).to(1)
    end
  end

  context 'when mid-checkout mutation (!was_in_cart && !cart?)' do
    before do
      order.update_column(:state, 'delivery')
      create(
        :stock_reservation,
        stock_item: stock_item,
        line_item: order.line_items.first,
        order: order,
        quantity: 1,
        expires_at: 1.minute.from_now
      )
    end

    it 'extends expires_at' do
      original = Spree::StockReservation.where(order_id: order.id).maximum(:expires_at)

      Timecop.freeze(2.minutes.from_now) do
        described_class.call(order: order, was_in_cart: false)
      end

      new_expires = Spree::StockReservation.where(order_id: order.id).maximum(:expires_at)
      expect(new_expires).to be > original
    end
  end

  context 'when reverting to cart (!was_in_cart && cart?)' do
    before do
      order.update_column(:state, 'cart')
      create(
        :stock_reservation,
        stock_item: stock_item,
        line_item: order.line_items.first,
        order: order,
        quantity: 1,
        expires_at: 5.minutes.from_now
      )
    end

    it 'releases reservations' do
      expect { described_class.call(order: order, was_in_cart: false) }
        .to change { Spree::StockReservation.where(order_id: order.id).count }.from(1).to(0)
    end
  end

  context 'when staying in cart (was_in_cart && cart?)' do
    before { order.update_column(:state, 'cart') }

    it 'is a no-op' do
      expect { described_class.call(order: order, was_in_cart: true) }
        .not_to change { Spree::StockReservation.where(order_id: order.id).count }
    end
  end

  it 'returns success' do
    order.update_column(:state, 'cart')
    expect(described_class.call(order: order, was_in_cart: true)).to be_success
  end
end
