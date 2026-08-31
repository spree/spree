require 'spec_helper'

RSpec.describe Spree::Purchase::Freight do
  let(:store) { @default_store }
  let(:carton) { create(:carton_package_type, store: store, length: 40, width: 30, height: 25) }
  let(:variant) { create(:variant, units_per_carton: 12, cartons_per_pallet: 40, carton_package_type: carton) }

  describe 'a cart' do
    let(:cart) { create(:cart, store: store) }

    it 'computes the rollup live, because the buyer is still changing it' do
      create(:line_item, cart: cart, order: nil, variant: variant, quantity: 12)
      expect(cart.reload.freight_summary.total_cartons).to eq(1)

      create(:line_item, cart: cart, order: nil, variant: variant, quantity: 12)
      expect(cart.reload.freight_summary.total_cartons).to eq(2)
    end

    it 'has none when nothing is in it' do
      expect(cart.freight_summary).to be_nil
    end
  end

  describe 'an order' do
    let(:order) { create(:order, store: store) }

    before { create(:line_item, order: order, variant: variant, quantity: 24) }

    it 'reads what the freight rate froze rather than the live catalog' do
      fulfillment = create(:shipment, order: order)
      snapshot = Spree::FreightSummary.new(
        lines: [Spree::FreightSummary::Line.new(units: 24, cartons: 2, pallets: 1, complete: true)]
      ).as_json
      create(:delivery_rate, fulfillment: fulfillment, selected: true, unpriced: true,
                             metadata: { 'freight_summary' => snapshot })

      # Repacking the product must not rewrite what already shipped.
      variant.update!(units_per_carton: 4)

      expect(order.reload.freight_summary.total_cartons).to eq(2)
    end

    it 'falls back to computing when the order shipped by parcel' do
      create(:shipment, order: order)

      expect(order.reload.freight_summary.total_cartons).to eq(2)
    end
  end
end
