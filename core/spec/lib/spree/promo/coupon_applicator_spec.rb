require 'spec_helper'

describe Spree::Promo::CouponApplicator do
  subject do
    Spree::Promo::CouponApplicator.new(order)
  end

  describe "#apply" do
    let(:order) { create(:order, :state => "payment", :coupon_code => "tenoff") }

    it "can apply a coupon code to an order" do
      flat_percent_calc = Spree::Calculator::FlatPercentItemTotal.create(:preferred_flat_percent => "10")
      promo = Spree::Promotion.create(:name => "Discount", :event_name => "spree.checkout.coupon_code_added", :code => "tenoff", :usage_limit => "10", :starts_at => DateTime.yesterday, :expires_at => DateTime.tomorrow)
      promo_rule = Spree::Promotion::Rules::ItemTotal.create(:preferred_operator => "gt", :preferred_amount => "1")
      promo_rule.update_attribute(:activator_id, promo.id)
      promo_action = Spree::Promotion::Actions::CreateAdjustment.create(:calculator_type => "Spree::Calculator::FlatPercentItemTotal")
      promo_action.update_attribute(:activator_id, promo.id)
      flat_percent_calc.update_attribute(:calculable_id, promo.id)
      Spree::Order.any_instance.stub(:payment_required? => false)
      Spree::Adjustment.any_instance.stub(:eligible => true)
      order.update_column(:state, "payment")
      order.coupon_code = "tenoff"

      subject.apply
      order.adjustments.first.label.should == "Promotion (#{promo.name})"
    end
  end
end
