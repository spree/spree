require 'spec_helper'

module Spree
  describe Api::V1::LineItemsController do
    let!(:order) do
     order = Factory(:order)
     order.line_items << Factory(:line_item)
     order
    end

    let(:product) { Factory(:product) }
    let(:attributes) { [:quantity, :price, :variant] }
    let(:resource_scoping) { { :order_id => order.to_param } }

    before do
      stub_authentication!
    end

    it "can learn how to create a new line item" do
      api_get :new
      json_response["attributes"].should == ["quantity", "price", "variant_id"]
      required_attributes = json_response["required_attributes"]
      required_attributes.should include("quantity", "variant_id")
    end

    context "as the order owner" do
      before do
        Order.any_instance.stub :user => current_api_user
      end

      it "can add a new line item to an existing order" do
        api_post :create, :line_item => { :variant_id => product.master.to_param, :quantity => 1 }
        response.status.should == 201
        json_response.should have_attributes(attributes)
        json_response["line_item"]["variant"]["name"].should_not be_blank
      end

      it "can update a line item on the order" do
        line_item = order.line_items.first
        api_put :update, :id => line_item.id, :line_item => { :quantity => 1000 }
      end
    end

    context "as just another user" do
      it "cannot add a new line item to the order" do
        api_post :create, :line_item => { :variant_id => product.master.to_param, :quantity => 1 }
        assert_unauthorized!
      end

      it "cannot update a line item on the order" do
        line_item = order.line_items.first
        api_put :update, :id => line_item.id, :line_item => { :quantity => 1000 }
        assert_unauthorized!
        line_item.reload.quantity.should_not == 1000
      end
    end

  end
end
