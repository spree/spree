require 'spec_helper'

module Spree
  describe Api::AddressesController do
    render_views

    before do
      stub_authentication!
      @address = create(:address)
    end

    context "with their own address" do
      before do
        Address.any_instance.stub :user => current_api_user
      end

      it "gets an address" do
        api_get :show, :id => @address.id
        json_response['address1'].should eq @address.address1
      end

      it "updates an address" do
        api_put :update, :id => @address.id,
                         :address => { :address1 => "123 Test Lane" }
        json_response['address1'].should eq '123 Test Lane'
      end
      
      it "receives the errors object if address is invalid" do
        api_put :update, :id => @address.id,
                         :address => { :address1 => "" }
                         
        json_response['error'].should_not be_nil
        json_response['errors'].should_not be_nil
        json_response['errors']['address1'].first.should eq "can't be blank"
      end
    end

    context "on somebody else's address" do
      before do
        Address.any_instance.stub :user => stub_model(Spree::LegacyUser)
      end

      it "cannot retreive address information" do
        api_get :show, :id => @address.id
        assert_unauthorized!
      end

      it "cannot update address information" do
        api_get :update, :id => @address.id
        assert_unauthorized!
      end
    end
  end
end
