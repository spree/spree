require 'spec_helper'

RSpec.describe 'freight serialization' do
  let(:store) { @default_store }
  let(:carton) { create(:carton_package_type, store: store, length: 40, width: 30, height: 25) }
  let(:variant) do
    create(:variant, units_per_carton: 12, cartons_per_pallet: 40, carton_weight: 10,
                     weight_unit: 'kg', carton_package_type: carton)
  end

  describe Spree::Api::V3::Admin::VariantSerializer do
    def render(record)
      described_class.new(record, params: { store: store, currency: store.default_currency }).to_h
    end

    it 'exposes the packing chain a merchant edits' do
      json = render(variant)

      expect(json['carton_package_type_id']).to eq(carton.prefixed_id)
      expect(json['cartons_per_pallet']).to eq(40)
      expect(json['carton_weight'].to_d).to eq(10)
      expect(json['units_per_pallet']).to eq(480)
    end

    it 'leaves the chain empty on a variant nobody packed' do
      json = render(create(:variant))

      expect(json['carton_package_type_id']).to be_nil
      expect(json['units_per_pallet']).to be_nil
    end
  end

  describe Spree::Api::V3::CartSerializer do
    let(:cart) { create(:cart, store: store) }

    it 'rolls the cart up for the forwarder' do
      create(:line_item, cart: cart, order: nil, variant: variant, quantity: 24)

      summary = described_class.new(cart.reload, params: { store: store }).to_h['freight_summary']

      expect(summary['total_cartons']).to eq(2)
      expect(summary['total_pallets']).to eq(1)
      expect(summary['complete']).to be(true)
    end

    it 'reports nothing for an empty cart' do
      json = described_class.new(cart, params: { store: store }).to_h

      expect(json['freight_summary']).to be_nil
    end
  end

  describe Spree::Api::V3::DeliveryRateSerializer do
    let(:fulfillment) { create(:shipment) }

    it 'says a freight rate is unpriced rather than free' do
      rate = create(:delivery_rate, fulfillment: fulfillment, cost: 0, unpriced: true)

      json = described_class.new(rate, params: { store: store }).to_h

      expect(json['unpriced']).to be(true)
      expect(json['display_cost']).to eq(Spree.t('delivery_rates.quoted_after_review'))
    end

    # A storefront rendering the total rather than the cost would otherwise
    # show "$0.00" over a container of goods nobody has quoted yet.
    it 'says the same on every money display, not just the cost' do
      rate = create(:delivery_rate, fulfillment: fulfillment, cost: 0, unpriced: true)

      json = described_class.new(rate, params: { store: store }).to_h

      expect(json['display_total']).to eq(Spree.t('delivery_rates.quoted_after_review'))
    end

    it 'carries the frozen summary the provider quoted against' do
      snapshot = Spree::FreightSummary.new(
        lines: [Spree::FreightSummary::Line.new(units: 48, cartons: 4, pallets: 1,
                                                volume: BigDecimal('0.12'), weight: BigDecimal('40'),
                                                complete: true)]
      ).as_json
      rate = create(:delivery_rate, fulfillment: fulfillment, cost: 0, unpriced: true,
                                    metadata: { 'freight_summary' => snapshot })

      summary = described_class.new(rate, params: { store: store }).to_h['freight_summary']

      expect(summary['total_cartons']).to eq(4)
      expect(summary['total_volume'].to_d).to eq(BigDecimal('0.12'))
    end

    it 'leaves an ordinary parcel rate priced and unsummarized' do
      rate = create(:delivery_rate, fulfillment: fulfillment, cost: 12)

      json = described_class.new(rate, params: { store: store }).to_h

      expect(json['unpriced']).to be(false)
      expect(json['freight_summary']).to be_nil
    end
  end
end
