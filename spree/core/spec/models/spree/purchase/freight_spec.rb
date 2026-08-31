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

    # Answering "nothing" is the common case — every retail cart — so it has
    # to be remembered too, or each serializer call walks the catalog again.
    it 'remembers that it has none rather than re-deriving it' do
      cart.freight_summary

      expect(cart).not_to receive(:build_freight_summary)
      expect(cart.freight_summary).to be_nil
    end

    # Remembering must not outlive the cart's contents: an item added after
    # the first read has to show up.
    it 'forgets what it remembered when the cart is reloaded' do
      expect(cart.freight_summary).to be_nil

      create(:line_item, cart: cart, order: nil, variant: variant, quantity: 12)

      expect(cart.reload.freight_summary.total_cartons).to eq(1)
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

    # Two freight shipments are still one load to the forwarder.
    it 'sums the frozen summaries across every fulfillment' do
      2.times do
        fulfillment = create(:shipment, order: order)
        snapshot = Spree::FreightSummary.new(
          lines: [Spree::FreightSummary::Line.new(units: 12, cartons: 1, pallets: 1,
                                                  volume: BigDecimal('0.03'), complete: true)]
        ).as_json
        create(:delivery_rate, fulfillment: fulfillment, selected: true, unpriced: true,
                               metadata: { 'freight_summary' => snapshot })
      end

      summary = order.reload.freight_summary

      expect(summary.total_cartons).to eq(2)
      expect(summary.total_volume).to eq(BigDecimal('0.06'))
    end

    # One variant split across two consignments is still one variant: each
    # part rounded its cartons up, so adding them would invent a pallet.
    it 're-rounds a variant split across consignments rather than adding' do
      [3, 9].each do |units|
        fulfillment = create(:shipment, order: order)
        snapshot = Spree::FreightSummary.new(
          lines: [Spree::FreightSummary::Line.new(variant_id: 'variant_abc', units: units,
                                                  units_per_carton: 12, cartons_per_pallet: 40,
                                                  cartons: 1, pallets: 1, complete: true)]
        ).as_json
        create(:delivery_rate, fulfillment: fulfillment, selected: true, unpriced: true,
                               metadata: { 'freight_summary' => snapshot })
      end

      summary = order.reload.freight_summary

      expect(summary.total_units).to eq(12)
      expect(summary.total_cartons).to eq(1)
      expect(summary.total_pallets).to eq(1)
    end

    # The sale already happened. Re-deriving it would mean a carton size
    # corrected next month silently rewrites what shipped last month.
    it 'reports nothing rather than re-deriving when no rate froze a summary' do
      create(:shipment, order: order)

      expect(order.reload.freight_summary).to be_nil
    end
  end
end
