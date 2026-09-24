require 'spec_helper'

RSpec.describe Spree::Fulfillments::Update do
  let(:store) { @default_store }
  let!(:delivery_method) { create(:delivery_method, store: store) }
  let(:order) { create(:order_with_line_items, store: store) }
  let(:fulfillment) { order.fulfillments.first }

  describe 'moving the fulfillment to another origin' do
    let(:other_location) do
      create(:stock_location, store: store, name: "Warehouse #{SecureRandom.hex(3)}",
                              propagate_all_variants: true, backorderable_default: true)
    end

    # Rates are quoted per origin, so leaving the old ones in place would offer
    # the customer a method the new warehouse may not even serve.
    it 're-quotes the delivery rates against the new location' do
      original_rate_ids = fulfillment.delivery_rates.map(&:id)

      result = described_class.call(
        fulfillment: fulfillment,
        fulfillment_attributes: { stock_location_id: other_location.id }
      )

      expect(result).to be_success
      expect(fulfillment.reload.stock_location_id).to eq(other_location.id)
      expect(fulfillment.delivery_rates.map(&:id)).not_to match_array(original_rate_ids)
      expect(fulfillment.selected_delivery_rate).to be_present
    end

    it 'leaves the rates alone when the location is merely resubmitted' do
      original_rate_ids = fulfillment.delivery_rates.map(&:id).sort

      described_class.call(
        fulfillment: fulfillment,
        fulfillment_attributes: { stock_location_id: fulfillment.stock_location_id }
      )

      expect(fulfillment.reload.delivery_rates.map(&:id).sort).to eq(original_rate_ids)
    end
  end

  describe 'cost' do
    let(:order) { create(:order_ready_to_ship, store: store, line_items_count: 2) }
    let(:other_location) do
      create(:stock_location, store: store, name: "Warehouse #{SecureRandom.hex(3)}",
                              propagate_all_variants: true, backorderable_default: true)
    end

    def update(**arguments)
      described_class.call(fulfillment: fulfillment, **arguments)
    end

    # The split quotes the parcel that breaks off its own rate, so an order
    # paid in full owes more than it paid. Pricing that parcel at nothing is
    # how staff put it right.
    it 'lets staff zero the charge a split added, and the order reads paid again' do
      paid_total = order.total
      fulfillment.transfer_to_location(order.line_items.first.variant, 1, fulfillment.stock_location).run!
      split_off = order.reload.fulfillments.max_by(&:id)
      expect(order.total).to be > paid_total

      result = described_class.call(fulfillment: split_off, cost: '0')

      expect(result).to be_success
      expect(split_off.reload.cost).to eq(0)
      expect(split_off.cost_source).to eq(Spree::Fulfillment::MANUAL_COST_SOURCE)
      expect(order.reload.total).to eq(paid_total)
      expect(order.payment_status).to eq('paid')
    end

    it 'charges a higher price, and the paid order owes the difference' do
      paid_total = order.total
      difference = BigDecimal('150.00') - fulfillment.cost

      result = update(cost: '150.00')

      expect(result).to be_success
      expect(fulfillment.reload.cost).to eq(BigDecimal('150.00'))
      expect(fulfillment).to be_cost_overridden
      expect(order.reload.delivery_total).to eq(BigDecimal('150.00'))
      expect(order.total).to eq(paid_total + difference)
      expect(order.payment_status).to eq('partially_paid')
    end

    it 'charges a lower price, and the paid order reads overcharged' do
      paid_total = order.total
      difference = fulfillment.cost - BigDecimal('7.25')

      update(cost: '7.25')

      expect(fulfillment.reload.cost).to eq(BigDecimal('7.25'))
      expect(order.reload.total).to eq(paid_total - difference)
      expect(order.payment_status).to eq('overcharged')
    end

    it 'keeps the cost through a rate change' do
      update(cost: '7.25')
      other_rate = fulfillment.delivery_rates.create!(delivery_method: create(:delivery_method, store: store), cost: 25)

      update(fulfillment_attributes: { selected_delivery_rate_id: other_rate.id })

      expect(fulfillment.reload.selected_delivery_rate).to eq(other_rate)
      expect(fulfillment.cost).to eq(BigDecimal('7.25'))
    end

    it 'keeps the cost through a move to another origin, which re-quotes every rate' do
      update(cost: '0')

      update(fulfillment_attributes: { stock_location_id: other_location.id })

      expect(fulfillment.reload.stock_location).to eq(other_location)
      expect(fulfillment.cost).to eq(0)
    end

    it 'leaves the cost alone when the update does not name one' do
      update(cost: '12.50')

      update(fulfillment_attributes: { tracking: 'DPD-1' })

      expect(fulfillment.reload.cost).to eq(BigDecimal('12.50'))
      expect(fulfillment).to be_cost_overridden
    end

    it 'hands the parcel back to its rate on an explicit nil' do
      rate_cost = fulfillment.selected_delivery_rate.cost
      update(cost: '0')

      result = update(cost: nil)

      expect(result).to be_success
      expect(fulfillment.reload.cost).to eq(rate_cost)
      expect(fulfillment.cost_source).to be_nil
      expect(order.reload.delivery_total).to eq(rate_cost)
    end

    it 'restates the new rate when a revert arrives with one' do
      update(cost: '0')
      other_rate = fulfillment.delivery_rates.create!(delivery_method: create(:delivery_method, store: store), cost: 25)

      update(fulfillment_attributes: { selected_delivery_rate_id: other_rate.id }, cost: nil)

      expect(fulfillment.reload.cost).to eq(25)
      expect(order.reload.delivery_total).to eq(25)
    end

    # A parcel that has left is frozen against re-quotes, not against staff.
    it 'lets staff price a parcel that has already shipped' do
      fulfillment.update_columns(status: 'fulfilled')

      update(cost: '0')

      expect(fulfillment.reload.cost).to eq(0)
    end

    it 'refuses a cost that is not an amount, and writes nothing' do
      # The last is more than the cost column holds, which would otherwise
      # fail the write with a database error.
      ['', '-1', '12 boxes', 'NaN', '123456789012'].each do |value|
        result = update(cost: value, fulfillment_attributes: { tracking: 'DPD-2' })

        expect(result).not_to be_success, "expected #{value.inspect} to be refused"
        expect(result.error.to_s).to eq(Spree.t('fulfillments.errors.invalid_cost'))
      end

      expect(fulfillment.reload.cost_source).to be_nil
      expect(fulfillment.tracking).not_to eq('DPD-2')
    end
  end

  describe 'hooks' do
    before { Spree.hooks.clear! }
    after { Spree.hooks.clear! }

    it 'lets a validate handler veto the move before anything is written' do
      original_location_id = fulfillment.stock_location_id
      other_location = create(:stock_location, store: store, name: "Blocked #{SecureRandom.hex(3)}")

      Spree.hooks.register('fulfillments.update.validate') do |flow|
        flow.reject!('this warehouse is at capacity') if flow.origin_changed?
      end

      result = described_class.call(
        fulfillment: fulfillment,
        fulfillment_attributes: { stock_location_id: other_location.id }
      )

      expect(result).to be_failure
      expect(fulfillment.reload.stock_location_id).to eq(original_location_id)
    end

    it 'notifies after_update handlers once the change is committed' do
      observed = nil
      Spree.hooks.register('fulfillments.update.after_update') { |flow| observed = flow.fulfillment.tracking }

      described_class.call(fulfillment: fulfillment, fulfillment_attributes: { tracking: 'XYZ789' })

      expect(observed).to eq('XYZ789')
    end
  end

  describe 'the deprecated shipment keywords' do
    it 'still updates through the old names, with a warning' do
      expect(Spree::Deprecation).to receive(:warn).at_least(:once)

      result = described_class.call(
        shipment: fulfillment,
        shipment_attributes: { tracking: 'ABC123' }
      )

      expect(result).to be_success
      expect(fulfillment.reload.tracking).to eq('ABC123')
    end
  end

  describe 'tracking' do
    it 'creates the primary delivery from the tracking shortcut' do
      fulfillment.deliveries.destroy_all

      result = described_class.call(
        fulfillment: fulfillment,
        fulfillment_attributes: { tracking: '421432', tracking_carrier: 'inpost' }
      )

      expect(result).to be_success
      expect(fulfillment.reload.tracking).to eq('421432')
      expect(fulfillment.primary_delivery.carrier).to eq('inpost')
    end

    # A corrected number is a different parcel as far as the carrier is
    # concerned, so its journey starts over.
    it 'corrects the primary delivery and resets its carrier status' do
      fulfillment.primary_delivery.update_columns(status: 'in_transit')

      described_class.call(fulfillment: fulfillment, fulfillment_attributes: { tracking: 'NEW-1' })

      expect(fulfillment.reload.deliveries.count).to eq(1)
      expect(fulfillment.primary_delivery.tracking_number).to eq('NEW-1')
      expect(fulfillment.primary_delivery.status).to eq('pending')
    end
  end
end
