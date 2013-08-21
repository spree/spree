require 'spec_helper'

module Spree
  describe PromotionItemHandlers do
    let(:line_item) { create(:line_item) }
    let(:order) { line_item.order }

    let(:promotion) { Promotion.create(name: "At line items") }
    let(:calculator) { Calculator::FlatPercentItemTotal.new(preferred_flat_percent: 10) }

    subject { PromotionItemHandlers.new(order, line_item) }

    shared_context "activates properly" do
      shared_context "creates the adjustment" do
        it "creates the adjustment" do
          expect {
            subject.activate
          }.to change { adjustable.adjustments.count }.by(1)
        end
      end

      context "promotion with no rules" do
        include_context "creates the adjustment"
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

        include_context "creates the adjustment"
      end

      context "promotion has item total rule" do
        let(:shirt) { create(:product) }
        let!(:rule) { Promotion::Rules::ItemTotal.create(preferred_operator: 'gt', preferred_amount: 50, promotion: promotion) }

        include_context "creates the adjustment"
      end
    end

    context "activates in LineItem level" do
      let!(:action) { Promotion::Actions::CreateItemAdjustment.create(promotion: promotion, calculator: calculator) }
      let(:adjustable) { line_item }

      include_context "activates properly"
    end

    context "activates in Order level" do
      let!(:action) { Promotion::Actions::CreateAdjustment.create(promotion: promotion, calculator: calculator) }
      let(:adjustable) { order }

      include_context "activates properly"
    end
  end
end
