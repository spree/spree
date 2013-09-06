require 'spec_helper'

module Spree
  module PromotionHandler
    describe Coupon do
      let(:order) { double("Order", coupon_code: "Huhu").as_null_object }
      let!(:promotion) { Promotion.create name: "promo" }

      subject { Coupon.new(order) }

      it "returns self in apply" do
        expect(subject.apply).to be_a Coupon
      end

      context "coupon code promotion doesnt exist" do
        it "doesnt fetch any promotion" do
          expect(subject.promotion).to be_blank
        end

        context "tries to apply" do
          it "populates error message" do
            subject.apply
            expect(subject.error).to eq Spree.t(:coupon_code_not_found)
          end
        end
      end

      context "existing coupon code promotion" do
        let!(:rule) { Promotion::Rules::CouponCode.create(promotion: promotion, code: "Huhu") }

        it "fetches with given code" do
          expect(subject.promotion).to eq promotion
        end

        context "right coupon given" do
          let(:order) { create(:order_with_line_items, :line_items_count => 3) }
          let!(:line_item) { order.contents.add create(:variant) }

          let(:calculator) { Calculator::FlatRate.new(preferred_amount: 10) }
          let!(:action) { Promotion::Actions::CreateItemAdjustments.create(promotion: promotion, calculator: calculator) }

          before { order.stub coupon_code: rule.code }

          it "successfully activates promo" do
            subject.apply
            expect(subject.success).to be_present
            order.line_items.each do |line_item|
              line_item.adjustments.count.should == 1
            end
          end
        end
      end

      pending "coupon already applied to the order" do
        subject.apply
        expect(subject.error).to eq Spree.t(:coupon_code_already_applied)
      end

      pending "coupon code hit max usage" do
        subject.apply
        expect(subject.error).to eq Spree.t(:coupon_code_max_usage)
      end
    end
  end
end
