require 'spec_helper'

describe Spree::StockReservations::Reserve do
  let(:store) { create(:store) }
  let(:variant) { create(:variant) }
  let!(:stock_location) { variant.stock_items.first.stock_location.tap { |sl| sl.update!(active: true) } }
  let!(:stock_item) { variant.stock_items.first.tap { |si| si.update!(backorderable: false); si.set_count_on_hand(10) } }
  let(:order) { create(:order, store: store) }
  let!(:line_item) { create(:line_item, order: order, variant: variant, quantity: 3) }

  subject(:result) { described_class.call(order: order) }

  context 'when stock_reservations_enabled is true' do
    before { Spree::Config[:stock_reservations_enabled] = true }
    after { Spree::Config[:stock_reservations_enabled] = true }

    it 'creates a reservation for each tracked line item' do
      expect { result }.to change(Spree::StockReservation, :count).by(1)
      expect(result).to be_success

      reservation = Spree::StockReservation.last
      expect(reservation.stock_item).to eq(stock_item)
      expect(reservation.line_item).to eq(line_item)
      expect(reservation.order).to eq(order)
      expect(reservation.quantity).to eq(3)
    end

    it 'sets expires_at according to the store TTL' do
      store.update!(preferred_stock_reservation_ttl_minutes: 7)
      Timecop.freeze do
        result
        expect(Spree::StockReservation.last.expires_at).to be_within(1.second).of(7.minutes.from_now)
      end
    end

    it 'is idempotent — calling twice updates the same reservation, not creating a new one' do
      described_class.call(order: order)
      expect { described_class.call(order: order) }.not_to change(Spree::StockReservation, :count)
    end

    it 'fails when stock is insufficient and rolls back' do
      stock_item.set_count_on_hand(1)
      expect { result }.not_to change(Spree::StockReservation, :count)
      expect(result).to be_failure
      expect(result.error.to_s).to include('available')
    end

    it 'subtracts other orders\' reservations when checking availability' do
      stock_item.set_count_on_hand(5)
      other_order = create(:order, store: store)
      other_line_item = create(:line_item, order: other_order, variant: variant, quantity: 4)
      create(
        :stock_reservation,
        stock_item: stock_item,
        line_item: other_line_item,
        order: other_order,
        quantity: 4,
        expires_at: 5.minutes.from_now
      )

      # Only 1 unit free; line_item wants 3
      expect(result).to be_failure
    end

    it 'accumulates per stock_item across line items so the same SKU twice cannot oversell' do
      # 5 units on hand, two line items each wanting 3 → total demand 6, must fail.
      stock_item.set_count_on_hand(5)
      create(:line_item, order: order, variant: variant, quantity: 3)

      expect(result).to be_failure
      expect(result.error.to_s).to include('available')
    end

    it 'skips backorderable stock items' do
      stock_item.update!(backorderable: true)
      expect { result }.not_to change(Spree::StockReservation, :count)
      expect(result).to be_success
    end

    it 'skips variants that do not track inventory' do
      variant.update!(track_inventory: false)
      expect { result }.not_to change(Spree::StockReservation, :count)
      expect(result).to be_success
    end
  end

  context 'when stock_reservations_enabled is false' do
    before { Spree::Config[:stock_reservations_enabled] = false }
    after { Spree::Config[:stock_reservations_enabled] = true }

    it 'is a no-op' do
      expect { result }.not_to change(Spree::StockReservation, :count)
      expect(result).to be_success
    end
  end
end
