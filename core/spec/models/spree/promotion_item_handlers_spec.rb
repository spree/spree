require 'spec_helper'

module Spree
  describe PromotionItemHandlers do
    let(:line_item) { create(:line_item) }
    let(:order) { line_item.order }

    let(:promotion) { Promotion.create(name: "At line items") }
    let(:calculator) { Calculator::FlatPercentItemTotal.new(preferred_flat_percent: 10) }

    subject { PromotionItemHandlers.new(line_item) }

    context "activates in LineItem level" do
      let!(:action) { Promotion::Actions::CreateItemAdjustment.create(promotion: promotion, calculator: calculator) }

      context "line item promotion with no rules" do
        it "creates the adjustment" do
          expect {
            subject.activate
          }.to change { line_item.adjustments.count }.by(1)
        end
      end

      context "promotion doesn't include item involved" do
        let(:shirt) { create(:product) }
        let!(:rule) { Promotion::Rules::Product.create(products: [shirt], promotion: promotion) }

        it "doesn't create adjustment" do
          expect {
            subject.activate
          }.not_to change { line_item.adjustments.count }
        end
      end

      context "promotion includes item involved" do
        let!(:rule) { Promotion::Rules::Product.create(products: [line_item.product], promotion: promotion) }

        it "creates the adjustment" do
          expect {
            subject.activate
          }.to change { line_item.adjustments.count }.by(1)
        end
      end

      context "promotion has item total rule" do
        let(:shirt) { create(:product) }
        let!(:rule) { Promotion::Rules::ItemTotal.create(preferred_operator: 'gt', preferred_amount: 50, promotion: promotion) }

        it "creates the adjustment" do
          expect {
            subject.activate
          }.to change { line_item.adjustments.count }.by(1)
        end
      end
    end
  end
end
