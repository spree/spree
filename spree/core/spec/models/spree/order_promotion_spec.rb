require 'spec_helper'

describe Spree::OrderPromotion, type: :model do
  subject { order.order_promotions.find_by(promotion: promotion) }

  let(:order) { create(:order_with_line_items) }
  let(:promotion) { create(:promotion_with_item_adjustment, code: 'test') }

  before do
    order.coupon_code = promotion.code
    Spree::PromotionHandler::Coupon.new(order).apply
    order.save!
    order.discounts.promotion.update_all(amount: -5.0)
  end

  context '#amount' do
    it 'equals sum of adjustments created by promotion' do
      expect(subject.amount).to eq(-5.0)
    end
  end

  context '#display_amount' do
    it 'returns Spree::Money instance with amount value and proper currency' do
      expect(subject.display_amount.to_s).to eq('-$5.00')
    end

    context 'different currency' do
      before { order.currency = 'EUR' }

      it 'return same currency as order' do
        expect(subject.currency).to eq('EUR')
        expect(subject.display_amount.currency).to eq('EUR')
      end
    end
  end
end
