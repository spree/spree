require 'spec_helper'

module Spree
  describe Api::V1::OrdersController do
    let!(:current_user) { stub_model(User) }
    let!(:order) { Factory(:order) }
    let(:attributes) { [:number, :item_total, :total,
                        :state, :adjustment_total, :credit_total,
                        :user_id, :created_at, :updated_at,
                        :completed_at, :payment_total, :shipment_state,
                        :payment_state, :email, :special_instructions] }

    render_views

    before do
      stub_authentication!
    end

    it "cannot view all orders" do
      api_get :index
      assert_unauthorized!
    end

    it "can view their own order" do
      Order.any_instance.stub :user => current_user
      api_get :show, :id => order.to_param
      response.status.should == 200
      json_response.should have_attributes(attributes)
    end

    it "can not view someone else's order" do
      Order.any_instance.stub :user => stub_model(User)
      api_get :show, :id => order.to_param
      assert_unauthorized!
    end
  end
end
