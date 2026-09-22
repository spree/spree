require 'spec_helper'

describe Spree::StockReservation, type: :model do
  describe 'validations' do
    let(:reservation) { build(:stock_reservation) }

    it 'requires positive integer quantity' do
      reservation.quantity = 0
      expect(reservation).to be_invalid
      expect(reservation.errors[:quantity]).to be_present

      reservation.quantity = -1
      expect(reservation).to be_invalid

      reservation.quantity = 1
      expect(reservation).to be_valid
    end

    it 'enforces uniqueness of line_item per stock_level' do
      reservation.save!
      duplicate = build(
        :stock_reservation,
        stock_level: reservation.stock_level,
        line_item: reservation.line_item,
        order: reservation.order
      )
      expect(duplicate).to be_invalid
      expect(duplicate.errors[:line_item_id]).to be_present
    end

    # Only a quantity change moves units between counters, so a hold that
    # changed levels would leave its units on the old one.
    it 'refuses to move a saved hold to another stock level' do
      reservation.save!
      reservation.stock_level = create(:stock_level)

      expect(reservation).to be_invalid
      expect(reservation.errors[:stock_level_id]).to be_present
    end
  end

  describe 'scopes' do
    let!(:active) { create(:stock_reservation, expires_at: 5.minutes.from_now) }
    let!(:expired) { create(:stock_reservation, :expired) }

    describe '.active' do
      it 'returns only reservations with future expires_at' do
        expect(Spree::StockReservation.active).to include(active)
        expect(Spree::StockReservation.active).not_to include(expired)
      end
    end

    describe '.expired' do
      it 'returns only reservations with past expires_at' do
        expect(Spree::StockReservation.expired).to include(expired)
        expect(Spree::StockReservation.expired).not_to include(active)
      end
    end

    describe '.for_order' do
      it 'returns reservations for the given order' do
        expect(Spree::StockReservation.for_order(active.order)).to include(active)
        expect(Spree::StockReservation.for_order(active.order)).not_to include(expired)
      end
    end
  end

  describe 'lifecycle helpers' do
    let(:reservation) { create(:stock_reservation, expires_at: 5.minutes.from_now) }

    describe '#active?' do
      it { expect(reservation).to be_active }

      it 'is false once expires_at passes' do
        reservation.update!(expires_at: 1.minute.ago)
        expect(reservation).not_to be_active
      end
    end
  end

  describe '.ttl_for' do
    it 'reads the order store preference when set' do
      order = create(:order)
      order.store.update!(preferred_stock_reservation_ttl_minutes: 15)
      expect(described_class.ttl_for(order)).to eq(15.minutes)
    end

    it 'falls back to ten minutes without a store to ask' do
      expect(described_class.ttl_for(nil)).to eq(10.minutes)
    end
  end

  # The level's reserved figure is kept by the rows themselves, so every path
  # that creates, resizes or removes a reservation — a checkout, a cart being
  # emptied, a line item removed mid-checkout — moves it without knowing.
  describe 'the reserved counter' do
    let(:reservation) { create(:stock_reservation, quantity: 3) }
    let(:level) { reservation.stock_level }

    it 'follows the row through its life' do
      expect(level.reload.reserved_count).to eq(3)

      reservation.update!(quantity: 5)
      expect(level.reload.reserved_count).to eq(5)

      reservation.destroy
      expect(level.reload.reserved_count).to eq(0)
    end

    it 'is given back when the line item is removed underneath it' do
      reservation

      reservation.line_item.destroy

      expect(level.reload.reserved_count).to eq(0)
    end

    it 'is given back when the cart is emptied' do
      cart = create(:cart_with_line_items, line_items_count: 1)
      cart_reservation = create(:stock_reservation, cart: cart, line_item: cart.line_items.first, quantity: 2)
      cart_level = cart_reservation.stock_level

      Spree::Carts::Empty.call(cart: cart)

      expect(cart_level.reload.reserved_count).to eq(0)
    end
  end

  describe 'cleanup via dependent: :destroy' do
    let(:reservation) { create(:stock_reservation) }

    it 'is destroyed when its order is destroyed' do
      reservation
      order = reservation.order
      expect { order.destroy }.to change(Spree::StockReservation, :count).by(-1)
    end

    it 'is destroyed when its line item is destroyed' do
      reservation
      expect { reservation.line_item.destroy }.to change(Spree::StockReservation, :count).by(-1)
    end

    it 'is destroyed when its stock item is destroyed' do
      reservation
      expect { reservation.stock_level.destroy }.to change(Spree::StockReservation, :count).by(-1)
    end
  end
end
