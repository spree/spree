require 'spec_helper'

describe Spree::OrdersController do

  let(:user) { create(:user) }
  let(:order) { user.orders.create }
  let(:promotion) { Spree::Promotion.create(:name => "TestPromo", :code => "TEST1", :expires_at => Time.now + 86400, :usage_limit => 99, :event_name => "spree.checkout.coupon_code_added", :match_policy => "any") }
  let(:coupon_code) { promotion.code }
  let(:invalid_coupon_code) { "12345" }

  before :each do
    controller.stub :current_user => user
    controller.stub :current_order => order
  end

  describe "#update" do

    it "applies a promotion to an order" do
      controller.should_receive(:fire_event).
                 with('spree.order.contents_changed')
      controller.should_receive(:fire_event).
                 with('spree.checkout.coupon_code_added', hash_including(:coupon_code => coupon_code))
      put :update, :order => { :coupon_code => coupon_code }
      order.coupon_code.should == coupon_code
      flash[:notice].should == I18n.t(:coupon_code_applied)
      response.should redirect_to(spree.cart_path)
    end

    it "renders orders#edit when coupon code is invalid" do
      controller.should_not_receive(:fire_event).
                 with('spree.checkout.coupon_code_added', hash_including(:coupon_code => invalid_coupon_code))
      put :update, :order => { :coupon_code => invalid_coupon_code }
      flash[:error].should == I18n.t(:promotion_not_found)
      response.should render_template :edit
    end

  end

end
