require 'spec_helper'

module Spree
  describe Api::ReturnAuthorizationsController do
    render_views

    let!(:order) { create(:shipped_order) }

    let(:product) { create(:product) }
    let(:attributes) { [:id, :reason, :amount, :state] }
    let(:resource_scoping) { { :order_id => order.to_param } }

    before do
      stub_authentication!
    end

    context "as the order owner" do
      before do
        Order.any_instance.stub :user => current_api_user
      end

      it "cannot see any return authorizations" do
        api_get :index
        assert_unauthorized!
      end

      it "cannot see a single return authorization" do
        api_get :show, :id => 1
        assert_unauthorized!
      end

      it "cannot learn how to create a new return authorization" do
        api_get :new
        assert_unauthorized!
      end

      it "cannot create a new return authorization" do
        api_post :create
        assert_unauthorized!
      end

      it "cannot update a return authorization" do
        api_put :update
        assert_not_found!
      end

      it "cannot delete a return authorization" do
        api_delete :destroy
        assert_not_found!
      end
    end

    context "as an admin" do
      sign_in_as_admin!

      it "can show return authorization" do
        FactoryGirl.create(:return_authorization, :order => order)
        return_authorization = order.return_authorizations.first
        api_get :show, :order_id => order.number, :id => return_authorization.id
        response.status.should == 200
        json_response.should have_attributes(attributes)
        json_response["state"].should_not be_blank
      end

      it "can get a list of return authorizations" do
        FactoryGirl.create(:return_authorization, :order => order)
        FactoryGirl.create(:return_authorization, :order => order)
        api_get :index, { :order_id => order.number }
        response.status.should == 200
        return_authorizations = json_response["return_authorizations"]
        return_authorizations.first.should have_attributes(attributes)
        return_authorizations.first.should_not == return_authorizations.last
      end

      it 'can control the page size through a parameter' do
        FactoryGirl.create(:return_authorization, :order => order)
        FactoryGirl.create(:return_authorization, :order => order)
        api_get :index, :order_id => order.number, :per_page => 1
        json_response['count'].should == 1
        json_response['current_page'].should == 1
        json_response['pages'].should == 2
      end

      it 'can query the results through a paramter' do
        FactoryGirl.create(:return_authorization, :order => order)
        expected_result = create(:return_authorization, :reason => 'damaged')
        order.return_authorizations << expected_result
        api_get :index, :q => { :reason_cont => 'damage' }
        json_response['count'].should == 1
        json_response['return_authorizations'].first['reason'].should eq expected_result.reason
      end

      it "can learn how to create a new return authorization" do
        api_get :new
        json_response["attributes"].should == ["id", "number", "state", "amount", "order_id", "reason", "created_at", "updated_at"]
        required_attributes = json_response["required_attributes"]
        required_attributes.should include("order")
      end

      it "can update a return authorization on the order" do
        FactoryGirl.create(:return_authorization, :order => order)
        return_authorization = order.return_authorizations.first
        api_put :update, :id => return_authorization.id, :return_authorization => { :amount => 19.99 }
        response.status.should == 200
        json_response.should have_attributes(attributes)
      end

      it "can add an inventory unit to a return authorization on the order" do
        FactoryGirl.create(:return_authorization, :order => order)
        return_authorization = order.return_authorizations.first
        inventory_unit = return_authorization.returnable_inventory.first
        inventory_unit.should be
        return_authorization.inventory_units.should be_empty
        api_put :add, :id => return_authorization.id, variant_id: inventory_unit.variant.id, quantity: 1
        response.status.should == 200
        json_response.should have_attributes(attributes)
        return_authorization.reload.inventory_units.should_not be_empty
      end

      it "can mark a return authorization as received on the order with an inventory unit" do
        FactoryGirl.create(:new_return_authorization, :order => order)
        return_authorization = order.return_authorizations.first
        return_authorization.state.should == "authorized"

        # prep (use a rspec context or a factory instead?)
        inventory_unit = return_authorization.returnable_inventory.first
        inventory_unit.should be
        return_authorization.inventory_units.should be_empty
        api_put :add, :id => return_authorization.id, variant_id: inventory_unit.variant.id, quantity: 1
        # end prep

        api_delete :receive, :id => return_authorization.id
        response.status.should == 200
        return_authorization.reload.state.should == "received"
      end

      it "cannot mark a return authorization as received on the order with no inventory units" do
        FactoryGirl.create(:new_return_authorization, :order => order)
        return_authorization = order.return_authorizations.first
        return_authorization.state.should == "authorized"
        api_delete :receive, :id => return_authorization.id
        response.status.should == 422
        return_authorization.reload.state.should == "authorized"
      end

      it "can cancel a return authorization on the order" do
        FactoryGirl.create(:new_return_authorization, :order => order)
        return_authorization = order.return_authorizations.first
        return_authorization.state.should == "authorized"
        api_delete :cancel, :id => return_authorization.id
        response.status.should == 200
        return_authorization.reload.state.should == "canceled"
      end

      it "can delete a return authorization on the order" do
        FactoryGirl.create(:return_authorization, :order => order)
        return_authorization = order.return_authorizations.first
        api_delete :destroy, :id => return_authorization.id
        response.status.should == 204
        lambda { return_authorization.reload }.should raise_error(ActiveRecord::RecordNotFound)
      end

      it "can add a new return authorization to an existing order" do
        api_post :create, :order_id => order.number, :return_authorization => { :amount => 14.22, :reason => "Defective" }
        response.status.should == 201
        json_response.should have_attributes(attributes)
        json_response["state"].should_not be_blank
      end
    end

    context "as just another user" do
      it "cannot add a return authorization to the order" do
        api_post :create, :return_autorization => { :order_id => order.number, :amount => 14.22, :reason => "Defective" }
        assert_unauthorized!
      end

      it "cannot update a return authorization on the order" do
        FactoryGirl.create(:return_authorization, :order => order)
        return_authorization = order.return_authorizations.first
        api_put :update, :id => return_authorization.id, :return_authorization => { :amount => 19.99 }
        assert_unauthorized!
        return_authorization.reload.amount.should_not == 19.99
      end

      it "cannot delete a return authorization on the order" do
        FactoryGirl.create(:return_authorization, :order => order)
        return_authorization = order.return_authorizations.first
        api_delete :destroy, :id => return_authorization.id
        assert_unauthorized!
        lambda { return_authorization.reload }.should_not raise_error
      end
    end
  end
end
