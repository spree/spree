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
end
