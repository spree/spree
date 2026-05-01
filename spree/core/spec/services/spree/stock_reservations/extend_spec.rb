require 'spec_helper'

describe Spree::StockReservations::Extend do
  let(:store) { create(:store, preferred_stock_reservation_ttl_minutes: 12) }
  let(:order) { create(:order, store: store) }
  let!(:reservation) { create(:stock_reservation, order: order, expires_at: 1.minute.from_now) }

  context 'when stock_reservations_enabled is true' do
    before { Spree::Config[:stock_reservations_enabled] = true }
    after { Spree::Config[:stock_reservations_enabled] = true }

    it 'pushes expires_at out by the store TTL' do
      Timecop.freeze do
        described_class.call(order: order)
        expect(reservation.reload.expires_at).to be_within(1.second).of(12.minutes.from_now)
      end
    end

    it 'updates only this order\'s reservations' do
      other_order = create(:order, store: store)
      other_reservation = create(:stock_reservation, order: other_order, expires_at: 1.minute.from_now)
      original_other_expires_at = other_reservation.expires_at

      described_class.call(order: order)

      expect(other_reservation.reload.expires_at).to be_within(1.second).of(original_other_expires_at)
    end
  end

  context 'when stock_reservations_enabled is false' do
    before { Spree::Config[:stock_reservations_enabled] = false }
    after { Spree::Config[:stock_reservations_enabled] = true }

    it 'leaves expires_at untouched' do
      original = reservation.expires_at
      described_class.call(order: order)
      expect(reservation.reload.expires_at).to be_within(1.second).of(original)
    end
  end
end
