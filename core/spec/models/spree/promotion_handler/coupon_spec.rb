require 'spec_helper'

module Spree
  module PromotionHandler
    describe Coupon do
      subject { Coupon.new(order) }

      pending "coupon already applied to the order" do
        subject.apply
        expect(subject.errors.first).to eq Spree.t(:coupon_code_already_applied)
      end

      pending "coupon code not found"

      pending "coupon code hit max usage" do
        subject.apply
        expect(subject.errors.first).to eq Spree.t(:coupon_code_max_usage)
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
