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
end
