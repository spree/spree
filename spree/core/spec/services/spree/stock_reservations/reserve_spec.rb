require 'spec_helper'

describe Spree::StockReservations::Reserve do
  let(:store) { create(:store) }
  let!(:stock_location) { create(:stock_location, store: store) }
  let(:variant) { create(:variant, product: create(:product, store: store)) }
  let!(:stock_level) do
    variant.stock_levels.find_by!(stock_location: stock_location).tap do |si|
      si.update!(backorderable: false)
      si.set_count_on_hand(10)
    end
  end
  let(:order) { create(:order, store: store) }
  let!(:line_item) { create(:line_item, order: order, variant: variant, quantity: 3) }

  subject(:result) { described_class.call(cart: order) }

  context 'when stock_reservations_enabled is true' do
    before { stub_store_preferences(store, stock_reservations_enabled: true) }

    it 'creates a reservation for each tracked line item' do
      expect { result }.to change(Spree::StockReservation, :count).by(1)
      expect(result).to be_success

      reservation = Spree::StockReservation.last
      expect(reservation.stock_level).to eq(stock_level)
      expect(reservation.line_item).to eq(line_item)
      expect(reservation.order).to eq(order)
      expect(reservation.quantity).to eq(3)
    end

    it 'sets expires_at according to the store TTL' do
      store.update!(preferred_stock_reservation_ttl_minutes: 7)
      freeze_time do
        result
        expect(Spree::StockReservation.last.expires_at).to be_within(1.second).of(7.minutes.from_now)
      end
    end

    it 'is idempotent — calling twice updates the same reservation, not creating a new one' do
      described_class.call(cart: order)
      expect { described_class.call(cart: order) }.not_to change(Spree::StockReservation, :count)
    end

    it 'holds the units on the level, and re-holding moves the figure by the difference' do
      expect { result }.to change { stock_level.reload.reserved_count }.from(0).to(3)

      line_item.update!(quantity: 5)

      expect { described_class.call(cart: order) }.to change { stock_level.reload.reserved_count }.from(3).to(5)
    end

    # A hold that lapsed and was revived by a later edit is a hold again, and
    # the counter — kept per row, not per call — still says so.
    it 'keeps an expired reservation it revives counted' do
      result
      Spree::StockReservation.last.update_column(:expires_at, 1.minute.ago)

      described_class.call(cart: order)

      expect(Spree::StockReservation.last).to be_active
      expect(stock_level.reload.reserved_count).to eq(3)
    end

    it 'fails when stock is insufficient and rolls back' do
      stock_level.set_count_on_hand(1)
      expect { result }.not_to change(Spree::StockReservation, :count)
      expect(result).to be_failure
      expect(result.error.to_s).to include('available')
      expect(stock_level.reload.reserved_count).to eq(0)
    end

    it 'subtracts other orders\' reservations when checking availability' do
      stock_level.set_count_on_hand(5)
      other_order = create(:order, store: store)
      other_line_item = create(:line_item, order: other_order, variant: variant, quantity: 4)
      create(
        :stock_reservation,
        stock_level: stock_level,
        line_item: other_line_item,
        order: other_order,
        quantity: 4,
        expires_at: 5.minutes.from_now
      )

      # Only 1 unit free; line_item wants 3
      expect(result).to be_failure
    end

    it 'accumulates per stock_level across line items so the same SKU twice cannot oversell' do
      # 5 units on hand, two line items each wanting 3 → total demand 6, must fail.
      stock_level.set_count_on_hand(5)
      create(:line_item, order: order, variant: variant, quantity: 3)

      expect(result).to be_failure
      expect(result.error.to_s).to include('available')
    end

    it 'holds two lines of one variant on the shelf they share' do
      second = create(:line_item, order: order, variant: variant, quantity: 3)

      expect(result).to be_success
      expect(Spree::StockReservation.where(line_item: [line_item, second]).pluck(:quantity)).to contain_exactly(3, 3)
      expect(stock_level.reload.reserved_count).to eq(6)
    end

    it 'holds each unit at the location the allocation takes it from' do
      stock_level.set_count_on_hand(2)
      other_level = create(:stock_location, store: store).stock_level_or_create(variant)
      other_level.update!(backorderable: false)
      other_level.set_count_on_hand(10)

      expect(result).to be_success
      expect(stock_level.reload.reserved_count).to eq(2)
      expect(other_level.reload.reserved_count).to eq(1)
    end

    it 'withdraws a hold the allocation no longer takes from that shelf' do
      result
      stock_level.update!(backorderable: true)

      described_class.call(cart: order)

      expect(Spree::StockReservation.for_order(order)).to be_empty
      expect(stock_level.reload.reserved_count).to eq(0)
    end

    it 'leaves a line no covered location stocks to the delivery check rather than refuse it' do
      variant.product.delivery_profile.default_origin_group.stock_locations =
        [create(:stock_location, store: store, propagate_all_variants: false)]

      expect(result).to be_success
      expect(Spree::StockReservation.for_order(order)).to be_empty
    end

    context 'when only one origin can deliver to the address' do
      let(:profile) { variant.product.delivery_profile }
      let(:netherlands) { Spree::Country.by_iso('NL') }
      let(:eu_location) { create(:stock_location, store: store, propagate_all_variants: false) }
      let!(:eu_level) do
        eu_location.stock_level_or_create(variant).tap do |level|
          level.update!(backorderable: false)
          level.set_count_on_hand(2)
        end
      end

      before do
        Spree::DeliveryMethod.delete_all
        eu_group = profile.delivery_origin_groups.create!(name: 'EU')
        profile.default_origin_group.stock_locations = [stock_location]
        eu_group.stock_locations = [eu_location]

        eu_zone = create(:delivery_zone_with_country, store: store, delivery_profile: profile,
                                                      delivery_origin_group: eu_group, country: netherlands)
        create(:delivery_method, store: store, delivery_profile: profile, delivery_origin_group: eu_group, delivery_zone: eu_zone)
      end

      it 'does not hold units that only an origin unable to reach the address would ship' do
        order.update!(ship_address: create(:address, country: netherlands, state: nil))

        expect(result).to be_success
        expect(eu_level.reload.reserved_count).to eq(2)
        expect(stock_level.reload.reserved_count).to eq(0)
      end

      it 'holds where the allocation packs while no address says what can ship' do
        order.update_columns(ship_address_id: nil)

        expect(result).to be_success
        expect(stock_level.reload.reserved_count + eu_level.reload.reserved_count).to eq(3)
      end
    end

    it 'skips backorderable stock items' do
      stock_level.update!(backorderable: true)
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
    before { stub_store_preferences(store, stock_reservations_enabled: false) }

    it 'is a no-op' do
      expect { result }.not_to change(Spree::StockReservation, :count)
      expect(result).to be_success
    end
  end
end
