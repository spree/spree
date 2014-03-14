require 'spec_helper'

describe Spree::PromotionAction do

  it "should force developer to implement 'perform' method" do
    expect { MyAction.new.perform }.to raise_error
  end

  describe '#credit_exists_on_order?' do
    let(:order) { create(:order_with_line_items, :state => "payment", :coupon_code => "tenoff") }
    let(:promo_action) { Spree::Promotion::Actions::CreateAdjustment.create(:calculator_type => "Spree::Calculator::FlatPercentItemTotal") }
    
    context 'when promo is applied' do
      before do
        flat_percent_calc = Spree::Calculator::FlatPercentItemTotal.create(:preferred_flat_percent => "10")
        promo = Spree::Promotion.create(:name => "Discount", :event_name => "spree.checkout.coupon_code_added", :code => "tenoff", :usage_limit => "10", :starts_at => DateTime.yesterday, :expires_at => DateTime.tomorrow)
        promo_rule = Spree::Promotion::Rules::ItemTotal.create(:preferred_operator => "gt", :preferred_amount => "1")
        promo_rule.update_attribute(:activator_id, promo.id)
        promo_action.update_attribute(:activator_id, promo.id)
        flat_percent_calc.update_attribute(:calculable_id, promo.id)
        Spree::Order.any_instance.stub(:payment_required? => false)
        Spree::Adjustment.any_instance.stub(:eligible => true)
        order.update_column(:state, "payment")
        order.coupon_code = "tenoff"
        Spree::Promo::CouponApplicator.new(order).apply
      end

      it 'should return true' do
        promo_action.credit_exists_on_order?(order).should be_true
      end 
    end

    context 'when promo is not applied' do
      it 'should return false' do
        promo_action.credit_exists_on_order?(order).should be_false
      end
    end
  end
end

