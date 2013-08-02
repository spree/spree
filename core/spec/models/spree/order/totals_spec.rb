require 'spec_helper'

module Spree
  describe Order do
    let(:order) { Order.create }
    let!(:shirt_item) { order.contents.add(create(:variant), 1) }
    let!(:bag_item) { order.contents.add(create(:variant), 1) }

    context "promotions" do
      let!(:promotion) { Promotion.create(name: "Huhuhu") }

      let(:promo_calculator) do
        Calculator::FlatPercentItemTotal.create(preferred_flat_percent: "10")
      end

      let!(:action) do
        Promotion::Actions::CreateAdjustment.create(calculator: promo_calculator)
      end

      before do
        promotion.actions << action
        action.perform(order: order)
      end

      context "saves more than one line item at once" do
        let(:params) do
          { line_items_attributes: {
              "0" => { id: shirt_item.id, quantity: 2 },
              "1" => { id: bag_item.id, quantity: 2 }
          } }
        end

        it "calculates descount properly" do
          order.update_attributes(params)
          expected_discount = - order.reload.item_total * (promo_calculator.preferred_flat_percent / 100)
          expect(order.adjustments.promotion.first.amount).to eql expected_discount.round(2)
        end
      end
    end
  end
end
