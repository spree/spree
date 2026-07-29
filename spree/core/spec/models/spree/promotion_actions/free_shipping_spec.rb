require 'spec_helper'

describe Spree::PromotionActions::FreeShipping, type: :model do
  let(:order) { create(:order_with_line_items, line_items_count: 1) }
  let(:promotion) { create(:promotion, kind: :automatic, code: nil, stores: [order.store]) }
  let(:action) { described_class.create!(promotion: promotion) }

  describe '#perform' do
    it 'writes a fulfillment discount covering the cost' do
      expect(action.perform(order: order, promotion: promotion)).to be(true)

      rows = order.discounts.reload
      expect(rows.map(&:fulfillment_id)).to match_array(order.fulfillments.ids)
      rows.each do |row|
        expect(row.amount).to eq(-row.fulfillment.cost)
      end
    end

    it 'persists rows even at zero cost' do
      order.fulfillments.each { |fulfillment| fulfillment.update_column(:cost, 0) }

      expect(action.perform(order: order, promotion: promotion)).to be(true)
      expect(order.discounts.reload.map(&:amount)).to all(eq(0))
      expect(order.has_free_shipping?).to be(true)
    end

    it 'reports no action without fulfillments' do
      order.fulfillments.destroy_all
      expect(action.perform(order: order, promotion: promotion)).to be(false)
    end
  end

  it 'has fulfillment discount scope and persists at zero' do
    expect(action.discount_scope).to eq(:fulfillment)
    expect(action.persist_at_zero?).to be(true)
    expect(action.free_shipping?).to be(true)
  end
end
