require 'spec_helper'

module Spree
  describe Spree::Api::V1::PaymentsController do
    let!(:order) { Factory(:order) }
    let!(:payment) { Factory(:payment, :order => order) }
    let!(:attributes) { [:id, :source_type, :source_id, :amount,
                         :payment_method_id, :response_code, :state, :avs_response, 
                         :created_at, :updated_at] }

    let(:resource_scoping) { { :order_id => order.to_param } }
    before do
      stub_authentication!
    end

    context "as a user" do
      context "when the order belongs to the user" do
        before do
          Order.any_instance.stub :user => current_api_user
        end

        it "can view the payments for their order" do
          api_get :index
          json_response.first.should have_attributes(attributes)
        end

        it "can learn how to create a new payment" do
          api_get :new
          json_response["attributes"].should == attributes.map(&:to_s)
          json_response["payment_methods"].should_not be_empty
          json_response["payment_methods"].first.should have_attributes([:id, :name, :description])
        end

        it "can create a new payment" do
          api_post :create, :payment => { :payment_method_id => PaymentMethod.first.id, :amount => 50 }
          response.status.should == 201
          json_response.should have_attributes(attributes)
        end

        it "can view a pre-existing payment's details" do
          api_get :show, :id => payment.to_param
          json_response.should have_attributes(attributes)
        end

        it "cannot authorize a payment" do
          api_put :authorize, :id => payment.to_param
          assert_unauthorized!
        end
      end

      context "when the order does not belong to the user" do
        before do
          Order.any_instance.stub :user => stub_model(User)
        end

        it "cannot view payments for somebody else's order" do
          api_get :index, :order_id => order.to_param
          assert_unauthorized!
        end
      end
    end

    context "as an admin" do
      sign_in_as_admin!

      it "can view the payments on any order" do
        api_get :index
        response.status.should == 200
        json_response.first.should have_attributes(attributes)
      end

      context "for a given payment" do

        it "can authorize" do
          api_put :authorize, :id => payment.to_param
          response.status.should == 200
        end

        it "returns a 422 status when authorization fails" do
          fake_response = stub(:success? => false, :to_s => "Could not authorize card")
          Spree::Gateway::Bogus.any_instance.should_receive(:authorize).and_return(fake_response)
          api_put :authorize, :id => payment.to_param
          response.status.should == 422
        end
      end

    end

  end
end
