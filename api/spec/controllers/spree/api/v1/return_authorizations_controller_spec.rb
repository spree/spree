require 'spec_helper'

module Spree
  describe Api::V1::ReturnAuthorizationsController do
    render_views

    let!(:order) do
     order = create(:order)
     order.line_items << create(:line_item)
     order.shipments << create(:shipment, :state => 'shipped')
     order.finalize!
     order.shipments.each(&:ready!)
     order.shipments.each(&:ship!)
     order
    end

    let(:product) { create(:product) }
    let(:attributes) { [:id, :reason, :amount, :state] }
    let(:resource_scoping) { { :order_id => order.to_param } }

    before do
      stub_authentication!
    end

    it "can learn how to create a new return authorization" do
      api_get :new
      json_response["attributes"].should == ["id", "number", "state", "amount", "order_id", "reason", "created_at", "updated_at"]
      required_attributes = json_response["required_attributes"]
      required_attributes.should include("order")
    end

    context "as the order owner" do
      before do
        Order.any_instance.stub :user => current_api_user
      end

      it "can add a new return authorization to an existing order" do
        api_post :create, :return_autorization => { :order_id => order.id, :amount => 14.22, :reason => "Defective" }
        response.status.should == 201
        json_response.should have_attributes(attributes)
        json_response["return_authorization"]["state"].should_not be_blank
      end

      it "can update a return authorization on the order" do
        order.return_authorizations << create(:return_authorization)
        return_authorization = order.return_authorizations.first
        api_put :update, :id => return_authorization.id, :return_authorization => { :amount => 19.99 }
        response.status.should == 200
        json_response.should have_attributes(attributes)
      end

      it "can delete a return authorization on the order" do
        order.return_authorizations << create(:return_authorization)
        return_authorization = order.return_authorizations.first
        api_delete :destroy, :id => return_authorization.id
        response.status.should == 204
        lambda { return_authorization.reload }.should raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "as just another user" do
      it "cannot add a return authorization to the order" do
        api_post :create, :return_autorization => { :order_id => order.id, :amount => 14.22, :reason => "Defective" }
        assert_unauthorized!
      end

      it "cannot update a return authorization on the order" do
        order.return_authorizations << create(:return_authorization)
        return_authorization = order.return_authorizations.first
        api_put :update, :id => return_authorization.id, :return_authorization => { :amount => 19.99 }
        assert_unauthorized!
        return_authorization.reload.amount.should_not == 19.99
      end

      it "cannot delete a return authorization on the order" do
        order.return_authorizations << create(:return_authorization)
        return_authorization = order.return_authorizations.first
        api_delete :destroy, :id => return_authorization.id
        assert_unauthorized!
        lambda { return_authorization.reload }.should_not raise_error(ActiveRecord::RecordNotFound)
      end
    end

  end
end
