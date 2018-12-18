require 'spec_helper'

describe Spree::OrderPromotion, type: :model do
  subject { create(:order_promotion, order: order, promotion: promotion) }

  let(:order) { create(:order_with_line_items) }
  let(:promotion) { create(:promotion_with_item_adjustment, code: 'test') }

  shared_context 'apply promo' do
    before do
      order.coupon_code = promotion.code
      Spree::PromotionHandler::Coupon.new(order).apply
      order.save!
      order.all_adjustments.promotion.update_all(amount: -5.0)
    end
  end

  context '#name' do
    it 'returns the same value as Promotion name' do
      expect(subject.name).to eq(promotion.name)
    end
  end

  context '#description' do
    it 'returns the same value as Promotion description' do
      expect(subject.description).to eq(promotion.description)
    end
  end

  context '#amount' do
    include_context 'apply promo'

    it 'equals sum of adjustments created by promotion' do
      expect(subject.amount).to eq(-5.0)
    end
  end

  context '#display_amount' do
    include_context 'apply promo'

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
