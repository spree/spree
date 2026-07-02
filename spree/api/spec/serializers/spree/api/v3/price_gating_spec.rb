require 'spec_helper'

# The prices_hidden gate injects a +hide_prices+ serializer param. These specs
# guard that the cart / order / line-item money surface — and every nested
# record embedded in it — honors it, so a guest can't recover a hidden catalog
# price through the cart, order, or any of their nested serializers.
RSpec.describe 'v3 Store serializer price gating' do
  let(:store) { @default_store || create(:store, default: true) }
  let(:order) { create(:order_with_line_items, store: store, line_items_count: 1) }

  def serialize(serializer, record = order, hide:)
    JSON.parse(
      serializer.new(record, params: { store: store, currency: order.currency, hide_prices: hide }).to_h.to_json
    )
  end

  describe Spree::Api::V3::CartSerializer do
    it 'nulls totals, store-credit, and nested line-item prices for gated guests' do
      hash = serialize(described_class, hide: true)

      expect(hash['total']).to be_nil
      expect(hash['display_total']).to be_nil
      expect(hash['item_total']).to be_nil
      expect(hash['store_credit_total']).to be_nil
      hash['items'].each do |li|
        expect(li['price']).to be_nil
        expect(li['display_price']).to be_nil
        expect(li['total']).to be_nil
      end
    end

    it 'serializes money fields normally when not gated' do
      hash = serialize(described_class, hide: false)

      expect(hash['total']).to be_present
      expect(hash['items'].first['price']).to be_present
    end
  end

  describe Spree::Api::V3::OrderSerializer do
    it 'nulls totals and store credit for gated guests' do
      hash = serialize(described_class, hide: true)

      expect(hash['total']).to be_nil
      expect(hash['display_total']).to be_nil
      expect(hash['store_credit_total']).to be_nil
      expect(hash['display_store_credit_total']).to be_nil
    end

    it 'serializes totals when not gated' do
      expect(serialize(described_class, hide: false)['total']).to be_present
    end
  end

  # Nested records embedded in a cart/order must honor hide_prices too, so a
  # gated guest can't recover amounts through discounts, payments, fulfillments,
  # or an applied gift card.
  describe 'nested cart/order serializers' do
    describe Spree::Api::V3::PaymentSerializer do
      let(:payment) { create(:payment) }

      it 'nulls the amount for gated guests' do
        hash = serialize(described_class, payment, hide: true)

        expect(hash['amount']).to be_nil
        expect(hash['display_amount']).to be_nil
      end

      it 'serializes the amount when not gated' do
        expect(serialize(described_class, payment, hide: false)['amount']).to be_present
      end
    end

    describe Spree::Api::V3::FulfillmentSerializer do
      let(:shipment) { create(:shipment) }

      it 'nulls cost, total, and tax for gated guests' do
        hash = serialize(described_class, shipment, hide: true)

        expect(hash['cost']).to be_nil
        expect(hash['total']).to be_nil
        expect(hash['tax_total']).to be_nil
      end

      it 'serializes the cost when not gated' do
        expect(serialize(described_class, shipment, hide: false)['cost']).to be_present
      end
    end

    describe Spree::Api::V3::GiftCardSerializer do
      let(:gift_card) { create(:gift_card) }

      it 'nulls balances for gated guests' do
        hash = serialize(described_class, gift_card, hide: true)

        expect(hash['amount']).to be_nil
        expect(hash['display_amount']).to be_nil
        expect(hash['amount_remaining']).to be_nil
      end

      it 'serializes balances when not gated' do
        expect(serialize(described_class, gift_card, hide: false)['amount']).to be_present
      end
    end

    describe Spree::Api::V3::DiscountSerializer do
      # The record is a lightweight applied-discount presenter responding to the
      # money methods; a struct keeps the gating assertion factory-free.
      let(:discount) do
        Struct.new(:name, :description, :code, :amount, :display_amount, :promotion, keyword_init: true).new(
          name: 'Promo', description: nil, code: 'SAVE10', amount: '5.0', display_amount: '$5.00', promotion: nil
        )
      end

      it 'nulls the amount for gated guests' do
        hash = serialize(described_class, discount, hide: true)

        expect(hash['amount']).to be_nil
        expect(hash['display_amount']).to be_nil
      end

      it 'serializes the amount when not gated' do
        expect(serialize(described_class, discount, hide: false)['amount']).to be_present
      end
    end
  end
end
