require 'spec_helper'

describe Spree::Promotion::Actions::FreeShipping, type: :model do
  let(:order) { create(:completed_order_with_totals) }
  let(:promotion) { create(:promotion) }
  let(:action) { Spree::Promotion::Actions::FreeShipping.create!(promotion: promotion) }
  let(:payload) { { order: order } }

  it_behaves_like 'an adjustment source'

  # From promotion spec:
  context '#perform' do
    before do
      order.shipments << create(:shipment)
      promotion.promotion_actions << action
    end

    it 'creates a discount with correct negative amount' do
      expect(order.shipments.count).to eq(2)
      # Costs are determined by the shipping calculator (default: 10.0)
      first_shipment_cost = order.shipments.first.cost
      last_shipment_cost = order.shipments.last.cost
      expect(first_shipment_cost).to be > 0
      expect(last_shipment_cost).to be > 0
      expect(action.perform(payload)).to be true
      expect(promotion.credits_count).to eq(2)
      expect(order.shipment_adjustments.count).to eq(2)
      expect(order.shipment_adjustments.first.amount.to_i).to eq(-first_shipment_cost.to_i)
      expect(order.shipment_adjustments.last.amount.to_i).to eq(-last_shipment_cost.to_i)
    end

    it 'does not create a discount when order already has one from this promotion' do
      expect(action.perform(payload)).to be true
      expect(action.perform(payload)).to be false
      expect(promotion.credits_count).to eq(2)
      expect(order.shipment_adjustments.count).to eq(2)
    end

    context 'when shipping methods are configured to be free' do
      before do
        order.shipments.update_all(cost: 0)
      end

      it 'can create adjustment with amount equal to 0' do
        expect(order.shipments.count).to eq(2)
        expect(order.shipments.first.cost).to eq(0)
        expect(order.shipments.last.cost).to eq(0)
        expect(action.perform(payload)).to be true
        expect(promotion.credits_count).to eq(2)
        expect(order.shipment_adjustments.count).to eq(2)
        expect(order.shipment_adjustments.first.amount.to_i).to eq(0)
        expect(order.shipment_adjustments.last.amount.to_i).to eq(0)
      end
    end
  end
end
