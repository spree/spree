require 'spec_helper'

describe Spree::OrdersController do

  let(:user) { create(:user) }
  let(:order) { user.spree_orders.create }
  let(:promotion) do
    Spree::Promotion.create({
      :name => "TestPromo",
      :code => "TEST1",
      :expires_at => 1.day.from_now,
      :created_at => 1.day.ago,
      :event_name => "spree.checkout.coupon_code_added",
      :match_policy => "any"
    }, :without_protection => true)
  end

  let(:coupon_code) { promotion.code }
  let(:invalid_coupon_code) { "12345" }

  before :each do
    controller.stub :current_user => user
    controller.stub :current_order => order
  end

  describe "#update" do
    it "renders orders#edit when coupon code is invalid" do
      controller.should_not_receive(:fire_event).
                 with('spree.checkout.coupon_code_added', hash_including(:coupon_code => invalid_coupon_code))
      spree_put :update, :order => { :coupon_code => invalid_coupon_code }
      flash[:error].should == I18n.t(:coupon_code_not_found)
      response.should render_template :edit
    end

  end

end
