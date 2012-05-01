require 'spec_helper'

module Spree
  describe Api::V1::AddressesController do
    render_views

    before do
      stub_authentication!
      @address = Factory(:address)
    end

    it "gets an address" do
      api_get :show, :id => @address.id
      json_response['address']['address1'].should eq @address.address1
    end

    it "updates an address" do
      api_put :update, :id => @address.id,
                       :address => { :address1 => "123 Test Lane" }
      json_response['address']['address1'].should eq '123 Test Lane'
    end
  end
end
