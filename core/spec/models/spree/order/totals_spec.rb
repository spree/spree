require 'spec_helper'

module Spree
  describe Order do
    let(:tax_calculator) { Calculator::DefaultTax.create }
    let!(:tax_rate) { create(:tax_rate, amount: 0.05, calculator: tax_calculator) }
    let!(:zone) { tax_rate.zone }

    let(:order) { Order.create }
    let(:variant) { create(:variant) }
    let!(:line_item) { order.contents.add(variant, 1) }

    context "tax is generated" do
      before do
        Zone.stub default_tax: zone
        order.create_tax_charge!
      end

      context "promo is added" do
        let(:promotion) { Promotion.create(name: "Huhuhu") }

        let(:calculator) do
          Calculator::FlatPercentItemTotal.create(preferred_flat_percent: "10")
        end

        let!(:action) do
          Promotion::Actions::CreateAdjustment.create(calculator: calculator, promotion: promotion)
        end

        it "re-calculate taxes" do
          expect {
            action.perform(order: order)
          }.to change { 
            order.adjustments.tax.first.amount.to_f
          }
        end
      end
    end
  end
end
