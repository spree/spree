require 'spec_helper'

module Spree
  describe Api::V1::OrdersController do
    render_views

    let!(:order) { Factory(:order) }
    let(:attributes) { [:number, :item_total, :total,
                        :state, :adjustment_total, :credit_total,
                        :user_id, :created_at, :updated_at,
                        :completed_at, :payment_total, :shipment_state,
                        :payment_state, :email, :special_instructions] }


    before do
      stub_authentication!
    end

    it "cannot view all orders" do
      api_get :index
      assert_unauthorized!
    end

    it "can view their own order" do
      Order.any_instance.stub :user => current_api_user
      api_get :show, :id => order.to_param
      response.status.should == 200
      json_response.should have_attributes(attributes)
    end

    it "can not view someone else's order" do
      Order.any_instance.stub :user => stub_model(User)
      api_get :show, :id => order.to_param
      assert_unauthorized!
    end

    it "can create an order" do
      variant = Factory(:variant)
      api_post :create, :order => { :line_items => { variant.to_param => 5 } }
      response.status.should == 200
      order = Order.last
      order.line_items.count.should == 1
      order.line_items.first.variant.should == variant
      order.line_items.first.quantity.should == 5
    end

    context "as an admin" do
      sign_in_as_admin!

      it "can view all orders" do
        api_get :index
        json_response["orders"].first.should have_attributes(attributes)
        json_response["count"].should == 1
        json_response["current_page"].should == 1
        json_response["pages"].should == 1
      end
    end
  end
end
