require 'spec_helper'

describe Spree::Order, type: :model do
  let(:order) { create(:order)   }
  let(:shirt) { create(:variant) }

  context 'adds item to cart and activates promo' do
    let(:promotion) { create(:promotion) }

    let!(:action) do
      Spree::Promotion::Actions::CreateAdjustment.create!(
        promotion:  promotion,
        calculator: Spree::Calculator::FlatPercentItemTotal.new(
          preferred_flat_percent: 10
        )
      )
    end

    before { order.contents.add(shirt, 1) }

    context 'item quantity changes' do
      it 'recalculates order adjustments' do
        expect { order.contents.add(shirt, 3) }
          .to change { order.adjustments.eligible.pluck(:amount) }
          .from([BigDecimal.new(-2)])
          .to([BigDecimal.new(-8)])
      end
    end
  end
end
