require 'spec_helper'

describe Spree::PromotionHandler::Page, type: :model do
  let(:order)     { create(:order_with_line_items, line_items_count: 1) }
  let(:promotion) { create(:promotion, path: '10off')                   }

  before do
    promotion.actions << Spree::Promotion::Actions::CreateItemAdjustments.create!(
      calculator: Spree::Calculator::FlatPercentItemTotal.new(
        preferred_flat_percent: 10
      )
    )
  end

  it 'activates at the right path' do
    expect(order.line_item_adjustments.count).to be(0)
    Spree::PromotionHandler::Page.new(order, promotion.path).activate
    expect(order.line_item_adjustments.count).to be(1)
  end

  context 'when promotion is expired' do
    before do
      promotion.update_attributes!(
        starts_at:  1.week.ago,
        expires_at: 1.day.ago
      )
    end

    it 'is not activated' do
      expect(order.line_item_adjustments.count).to be(0)
      Spree::PromotionHandler::Page.new(order, promotion.path).activate
      expect(order.line_item_adjustments.count).to be(0)
    end
  end

  it 'does not activate at the wrong path' do
    expect(order.line_item_adjustments.count).to be(0)
    Spree::PromotionHandler::Page.new(order, 'wrongpath').activate
    expect(order.line_item_adjustments.count).to be(0)
  end
end
