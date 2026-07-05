require 'spec_helper'

describe Spree::StockReservation, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:stock_item).class_name('Spree::StockItem').without_validating_presence }
    it { is_expected.to belong_to(:line_item).class_name('Spree::LineItem').without_validating_presence }
    it { is_expected.to belong_to(:order).class_name('Spree::Order').without_validating_presence }
  end

  describe 'validations' do
    let(:reservation) { build(:stock_reservation) }

    it { is_expected.to validate_presence_of(:quantity) }
    it { is_expected.to validate_presence_of(:expires_at) }

    it 'requires positive integer quantity' do
      reservation.quantity = 0
      expect(reservation).to be_invalid
      expect(reservation.errors[:quantity]).to be_present

      reservation.quantity = -1
      expect(reservation).to be_invalid

      reservation.quantity = 1
      expect(reservation).to be_valid
    end

    it 'enforces uniqueness of line_item per stock_item' do
      reservation.save!
      duplicate = build(
        :stock_reservation,
        stock_item: reservation.stock_item,
        line_item: reservation.line_item,
        order: reservation.order
      )
      expect(duplicate).to be_invalid
      expect(duplicate.errors[:line_item_id]).to be_present
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

    it 'falls back to the global default_stock_reservation_ttl_minutes' do
      Spree::Config[:default_stock_reservation_ttl_minutes] = 7
      expect(described_class.ttl_for(nil)).to eq(7.minutes)
    ensure
      Spree::Config[:default_stock_reservation_ttl_minutes] = 10
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
      expect { reservation.stock_item.destroy }.to change(Spree::StockReservation, :count).by(-1)
    end
  end
end
