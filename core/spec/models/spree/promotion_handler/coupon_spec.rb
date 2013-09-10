require 'spec_helper'

module Spree
  module PromotionHandler
    describe Coupon do
      let(:order) { double("Order", coupon_code: "10off").as_null_object }

      subject { Coupon.new(order) }

      it "returns self in apply" do
        expect(subject.apply).to be_a Coupon
      end


      context "coupon code promotion doesnt exist" do
        before { Promotion.create name: "promo", :code => nil }

        it "doesnt fetch any promotion" do
          expect(subject.promotion).to be_blank
        end

        context "with no actions defined" do
          before { Promotion.create name: "promo", :code => "10off" }

          it "populates error message" do
            subject.apply
            expect(subject.error).to eq Spree.t(:coupon_code_not_found)
          end
        end
      end

      context "existing coupon code promotion" do
        let!(:promotion) { Promotion.create name: "promo", :code => "10off"  }
        
        it "fetches with given code" do
          expect(subject.promotion).to eq promotion
        end

        context "right coupon given" do
          let(:order) { create(:order_with_line_items, :line_items_count => 3) }
          let!(:line_item) { order.contents.add create(:variant) }

          let(:calculator) { Calculator::FlatRate.new(preferred_amount: 10) }
          let!(:action) { Promotion::Actions::CreateItemAdjustments.create(promotion: promotion, calculator: calculator) }

          before { order.stub :coupon_code => "10off" }

          it "successfully activates promo" do
            subject.apply
            expect(subject.success).to be_present
            order.line_items.each do |line_item|
              line_item.adjustments.count.should == 1
            end
          end

          it "coupon already applied to the order" do
            subject.apply
            expect(subject.success).to be_present
            subject.apply
            expect(subject.error).to eq Spree.t(:coupon_code_already_applied)
          end
        end
      end

      pending "coupon code hit max usage" do
        subject.apply
        expect(subject.error).to eq Spree.t(:coupon_code_max_usage)
      end
    end
  end
end
