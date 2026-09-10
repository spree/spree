require 'spec_helper'

describe Spree::StockReservations::ExpireJob do
  it 'removes expired reservations and leaves active ones in place' do
    expired_a = create(:stock_reservation, :expired)
    expired_b = create(:stock_reservation, :expired)
    active = create(:stock_reservation, expires_at: 5.minutes.from_now)

    expect { described_class.perform_now }.to change(Spree::StockReservation, :count).by(-2)
    expect(Spree::StockReservation.where(id: [expired_a.id, expired_b.id])).to be_empty
    expect(Spree::StockReservation.find(active.id)).to be_present
  end

  it 'gives an expired reservation\'s units back to its level and leaves an active hold counted' do
    expired = create(:stock_reservation, :expired, quantity: 2)
    active = create(:stock_reservation, quantity: 3, expires_at: 5.minutes.from_now)

    described_class.perform_now

    expect(expired.stock_level.reload.reserved_count).to eq(0)
    expect(active.stock_level.reload.reserved_count).to eq(3)
  end
end
