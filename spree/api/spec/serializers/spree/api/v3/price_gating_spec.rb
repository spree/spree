require 'spec_helper'

# The prices_hidden gate injects a +hide_prices+ serializer param. These specs
# guard that the cart / order / line-item money surface honors it — so a guest
# can't recover a hidden catalog price via the cart or order.
RSpec.describe 'v3 Store serializer price gating' do
  let(:store) { @default_store || create(:store, default: true) }
  let(:order) { create(:order_with_line_items, store: store, line_items_count: 1) }

  def serialize(serializer, hide:)
    JSON.parse(
      serializer.new(order, params: { store: store, currency: order.currency, hide_prices: hide }).to_h.to_json
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
    it 'nulls totals for gated guests' do
      hash = serialize(described_class, hide: true)

      expect(hash['total']).to be_nil
      expect(hash['display_total']).to be_nil
    end
  end
end
