require 'spec_helper'

describe Spree::Promo::CouponApplicator do
  subject do
    Spree::Promo::CouponApplicator.new(order)
  end

  describe "#apply" do
    let(:order) do
      create(:order_with_line_items,
             :line_items_count => 1,
             :state => "payment",
             :coupon_code => "tenoff")
    end

    it "can apply a coupon code to an order" do
      flat_rate = Spree::Calculator::FlatRate.create(:preferred_amount => "10")
      promo = Spree::Promotion.create(:name => "Discount", :event_name => "spree.checkout.coupon_code_added", :code => "tenoff", :usage_limit => "10", :starts_at => DateTime.yesterday, :expires_at => DateTime.tomorrow)
      promo_action = Spree::Promotion::Actions::CreateAdjustment.new(:promotion => promo)
      promo_action.calculator = flat_rate
      promo_action.save
      order.coupon_code = "tenoff"

      subject.apply
      order.adjustments.first.label.should == "Promotion (#{promo.name})"
    end
  end
end
