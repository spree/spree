require 'spec_helper'

module Spree::Api
  describe OrdersController do
    render_views

    before do
      stub_authentication!
    end

    context "with an available promotion" do
      let!(:order) { create(:order_with_line_items, :line_items_count => 1) }
      let!(:promotion) do
        promotion = Spree::Promotion.create(name: "10% off", code: "10off")
        calculator = Spree::Calculator::FlatPercentItemTotal.create(preferred_flat_percent: "10")
        action = Spree::Promotion::Actions::CreateItemAdjustments.create(calculator: calculator)
        promotion.actions << action
        promotion
      end

      it "can apply a coupon code to the order" do
        order.total.should == 110.00
        api_put :apply_coupon_code, :id => order.to_param, :coupon_code => "10off", :order_token => order.token
        response.status.should == 200
        order.reload.total.should == 109.00
        json_response["success"].should == "The coupon code was successfully applied to your order."
        json_response["error"].should be_blank
        json_response["successful"].should be true
      end

      context "with an expired promotion" do
        before do
          promotion.starts_at = 2.weeks.ago
          promotion.expires_at = 1.week.ago
          promotion.save
        end

        it "fails to apply" do
          api_put :apply_coupon_code, :id => order.to_param, :coupon_code => "10off", :order_token => order.token
          response.status.should == 422
          json_response["success"].should be_blank
          json_response["error"].should == "The coupon code is expired"
          json_response["successful"].should be false
        end
      end
    end
  end
end
