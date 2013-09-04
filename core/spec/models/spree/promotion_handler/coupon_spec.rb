require 'spec_helper'

module Spree
  module PromotionHandler
    describe Coupon do
      let(:order) { double("Order", coupon_code: "Huhu").as_null_object }
      let!(:promotion) { Promotion.create name: "promo" }

      subject { Coupon.new(order) }

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
      end

      pending "coupon already applied to the order" do
        subject.apply
        expect(subject.error).to eq Spree.t(:coupon_code_already_applied)
      end

      pending "coupon code hit max usage" do
        subject.apply
        expect(subject.error).to eq Spree.t(:coupon_code_max_usage)
      end

      context "existing eligible promo" do
        context "right coupon given" do
          pending "successfully apply coupon"
        end

        context "wrong coupon given" do
          pending "coupon code not eligible"
        end
      end
    end
  end
end
