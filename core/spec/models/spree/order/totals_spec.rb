require 'spec_helper'

module Spree
  describe Order, type: :model do
    let(:store) { create(:store) }
    let(:order) { create(:order, store: store) }
    let(:shirt) { create(:variant) }

    context 'adds item to cart and activates promo' do
      let(:promotion) { create(:promotion, name: 'Huhu', stores: [store]) }
      let(:calculator) { Calculator::FlatPercentItemTotal.new(preferred_flat_percent: 10) }
      let!(:action) { Promotion::Actions::CreateAdjustment.create(promotion: promotion, calculator: calculator) }

      before { Spree::Cart::AddItem.call(order: order, variant: shirt).value }

      context 'item quantity changes' do
        it 'recalculates order adjustments' do
          expect do
            Spree::Cart::AddItem.call(order: order, variant: shirt, quantity: 3)
          end.to change { order.adjustments.eligible.pluck(:amount) }
        end
      end
    end
  end
end
