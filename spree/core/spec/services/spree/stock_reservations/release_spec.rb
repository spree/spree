require 'spec_helper'

describe Spree::StockReservations::Release do
  let(:order) { create(:order) }

  it 'deletes every reservation belonging to the order' do
    other_order = create(:order)
    reservation_a = create(:stock_reservation, order: order)
    line_item_b = create(:line_item, order: order)
    reservation_b = create(:stock_reservation, order: order, line_item: line_item_b)
    untouched = create(:stock_reservation, order: other_order)

    expect { described_class.call(order: order) }.to change(Spree::StockReservation, :count).by(-2)
    expect(Spree::StockReservation.where(id: [reservation_a.id, reservation_b.id])).to be_empty
    expect(Spree::StockReservation.find(untouched.id)).to be_present
  end

  it 'gives the held units back to the level' do
    reservation = create(:stock_reservation, order: order, quantity: 4)
    level = reservation.stock_level
    level.adjust_reserved_count(4)

    described_class.call(order: order)

    expect(level.reload.reserved_count).to eq(0)
  end

  it 'returns success even when no reservations exist' do
    result = described_class.call(order: order)
    expect(result).to be_success
  end
end
