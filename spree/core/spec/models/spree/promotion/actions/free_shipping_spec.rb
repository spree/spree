require 'spec_helper'

describe Spree::Promotion::Actions::FreeShipping, type: :model do
  let(:order) { create(:completed_order_with_totals) }
  let(:promotion) { create(:promotion) }
  let(:action) { described_class.create!(promotion: promotion) }
  let(:payload) { { order: order } }

  context '#perform' do
    before do
      order.shipments << create(:shipment)
      promotion.promotion_actions << action
    end

    it 'creates a discount line per shipment with the negated cost' do
      expect(order.shipments.count).to eq(2)
      # Costs are determined by the shipping calculator (default: 10.0)
      expect(order.shipments.map(&:cost)).to all(be > 0)

      expect(action.perform(payload)).to be true

      expect(order.fulfillment_discount_lines.count).to eq(2)
      expect(order.fulfillment_discount_lines.map(&:amount)).to eq(order.shipments.map { |s| -s.cost })
    end

    it 'upserts rather than duplicates on repeated performs' do
      expect(action.perform(payload)).to be true
      expect(action.perform(payload)).to be true

      expect(order.fulfillment_discount_lines.count).to eq(2)
    end

    context 'when shipping methods are configured to be free' do
      before do
        order.shipments.update_all(cost: 0)
      end

      it 'writes no discount lines but still counts as activated' do
        # Activation success is what connects the promotion to the order —
        # the discount line materializes once a paid rate is selected.
        expect(action.perform(payload)).to be true
        expect(order.fulfillment_discount_lines).to be_empty
      end
    end

    context 'when a shipment cost drops to zero after a line was written' do
      it 'removes the now-zero discount line on the next perform' do
        action.perform(payload)
        expect(order.fulfillment_discount_lines.count).to eq(2)

        order.shipments.first.update_columns(cost: 0)
        action.perform(payload)

        expect(order.fulfillment_discount_lines.count).to eq(1)
      end
    end
  end

  context 'when the order has no shipments' do
    let(:order) { create(:order) }

    it 'does not count as activated' do
      expect(action.perform(payload)).to be false
    end
  end
end
