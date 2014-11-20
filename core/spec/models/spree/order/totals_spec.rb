require 'spec_helper'

module Spree
  describe Order, :type => :model do
    let(:order) { Order.create }
    let(:shirt) { create(:variant) }

    context "adds item to cart and activates promo" do
      let(:promotion) { Promotion.create name: 'Huhu' }
      let(:calculator) { Calculator::FlatPercentItemTotal.new(:preferred_flat_percent => 10) }
      let!(:action) { Promotion::Actions::CreateAdjustment.create(promotion: promotion, calculator: calculator) }

      before { order.contents.add(shirt, 1) }

      context "item quantity changes" do
        it "recalculates order adjustments" do
          expect {
            order.contents.add(shirt, 3)
          }.to change { order.adjustments.eligible.pluck(:amount) }
        end
      end
    end
  end
end
