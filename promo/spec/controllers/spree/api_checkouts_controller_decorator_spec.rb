require 'spec_helper'
require 'spree/api/testing_support/controller_hacks'
require 'spree/api/testing_support/helpers'

module Spree
  describe Api::CheckoutsController do
    include Spree::Api::TestingSupport::Helpers
    include Spree::Api::TestingSupport::ControllerHacks
    render_views

    before(:each) do
      stub_authentication!
      Spree::Config[:track_inventory_levels] = false
      country_zone = create(:zone, :name => 'CountryZone')
      @state = create(:state)
      @country = @state.country
      country_zone.members.create(:zoneable => @country)

      @shipping_method = create(:shipping_method, :zone => country_zone)
      @payment_method = create(:payment_method)
    end

    after do
      Spree::Config[:track_inventory_levels] = true
    end

    context "PUT 'update'" do
      before(:each) do
        Order.any_instance.stub(:confirmation_required? => true)
        Order.any_instance.stub(:payment_required? => true)
      end

      it "can apply a coupon code to the order" do
        flat_percent_calc = Spree::Calculator::FlatPercentItemTotal.create(:preferred_flat_percent => "10")
        promo = Spree::Promotion.create(:name => "Discount", :event_name => "spree.checkout.coupon_code_added", :code => "tenoff", :usage_limit => "10", :starts_at => DateTime.yesterday, :expires_at => DateTime.tomorrow)
        promo_rule = Spree::Promotion::Rules::ItemTotal.create(:preferred_operator => "gt", :preferred_amount => "1")
        promo_rule.update_attribute(:activator_id, promo.id)
        promo_action = Spree::Promotion::Actions::CreateAdjustment.create(:calculator_type => "Spree::Calculator::FlatPercentItemTotal")
        promo_action.update_attribute(:activator_id, promo.id)
        flat_percent_calc.update_attribute(:calculable_id, promo.id)
        Spree::Order.any_instance.stub(:payment_required? => false)
        Spree::Adjustment.any_instance.stub(:eligible => true)
        new_order = create(:order)
        new_order.update_column(:state, "payment")
        api_put :update, :id => new_order.to_param, :order => { :coupon_code => 'tenoff' }
        new_order.adjustments.first.label.should == "Promotion (#{promo.name})"
      end
    end
  end
end
