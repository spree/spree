require 'spec_helper'

module Spree
  describe Api::LineItemsController do
    render_views

    let!(:order) { create(:order_with_line_items) }

    let(:product) { create(:product) }
    let(:attributes) { [:id, :quantity, :price, :variant, :total, :display_amount, :single_display_amount] }
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

    context "authenticating with a token" do
      it "can add a new line item to an existing order" do
        api_post :create, :line_item => { :variant_id => product.master.to_param, :quantity => 1 }, :order_token => order.token
        response.status.should == 201
        json_response.should have_attributes(attributes)
        json_response["variant"]["name"].should_not be_blank
      end
    end

    context "as the order owner" do
      before do
        Order.any_instance.stub :user => current_api_user
      end

      it "can add a new line item to an existing order" do
        api_post :create, :line_item => { :variant_id => product.master.to_param, :quantity => 1 }
        response.status.should == 201
        json_response.should have_attributes(attributes)
        json_response["variant"]["name"].should_not be_blank
      end

      it "increases a line item's quantity if it exists already" do
        order.line_items.create(:variant_id => product.master.id, :quantity => 10)
        api_post :create, :line_item => { :variant_id => product.master.to_param, :quantity => 1 }
        response.status.should == 201
        order.reload
        order.line_items.count.should == 6 # 5 original due to factory, + 1 in this test
        json_response.should have_attributes(attributes)
        json_response["quantity"].should == 11
      end

      it "can update a line item on the order" do
        line_item = order.line_items.first
        api_put :update, :id => line_item.id, :line_item => { :quantity => 1000 }
        response.status.should == 200
        json_response.should have_attributes(attributes)
      end

      it "can delete a line item on the order" do
        line_item = order.line_items.first
        api_delete :destroy, :id => line_item.id
        response.status.should == 204
        lambda { line_item.reload }.should raise_error(ActiveRecord::RecordNotFound)
      end

      context "order contents changed after shipments were created" do
        let!(:order) { Order.create }
        let!(:line_item) { order.contents.add(product.master) }

        before { order.create_proposed_shipments }

        it "clear out shipments on create" do
          expect(order.reload.shipments).not_to be_empty
          api_post :create, :line_item => { :variant_id => product.master.to_param, :quantity => 1 }
          expect(order.reload.shipments).to be_empty
        end

        it "clear out shipments on update" do
          expect(order.reload.shipments).not_to be_empty
          api_put :update, :id => line_item.id, :line_item => { :quantity => 1000 }
          expect(order.reload.shipments).to be_empty
        end
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

      it "cannot delete a line item on the order" do
        line_item = order.line_items.first
        api_delete :destroy, :id => line_item.id
        assert_unauthorized!
        lambda { line_item.reload }.should_not raise_error
      end
    end
  end
end
