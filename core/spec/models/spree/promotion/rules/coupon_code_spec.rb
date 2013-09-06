require 'spec_helper'

module Spree
  class Promotion
    module Rules
      describe CouponCode do
        it "validates presence of code" do
          subject.valid?
          expect(subject).to have(1).error_on(:code)

          subject.code = "Huhu"
          expect(subject).to have(0).error_on(:code)
        end

        context "matches order coupon code" do
          let(:order) { double("Order", coupon_code: "Huhu") }

          before { subject.stub code: order.coupon_code }

          it { expect(subject).to be_eligible(order) }
        end

        context "doesnt match order coupon code" do
          let(:order) { double("Order", coupon_code: "Huhu") }

          before { subject.stub code: "other" }

          it { expect(subject).not_to be_eligible(order) }
        end
      end
    end
  end
end
