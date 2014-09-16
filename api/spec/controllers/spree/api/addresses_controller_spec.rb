require 'spec_helper'

module Spree
  describe Api::AddressesController do
    render_views

    before do
      stub_authentication!
      @address = create(:address)
      @order = create(:order, :bill_address => @address)
    end

    context "with their own address" do
      before do
        Order.any_instance.stub :user => current_api_user
      end

      it "gets an address" do
        api_get :show, :id => @address.id, :order_id => @order.number
        json_response['address1'].should eq @address.address1
      end

      it "updates an address" do
        api_put :update, :id => @address.id, :order_id => @order.number,
                         :address => { :address1 => "123 Test Lane" }
        json_response['address1'].should eq '123 Test Lane'
      end

      it "receives the errors object if address is invalid" do
        api_put :update, :id => @address.id, :order_id => @order.number,
                         :address => { :address1 => "" }

        json_response['error'].should_not be_nil
        json_response['errors'].should_not be_nil
        json_response['errors']['address1'].first.should eq "can't be blank"
      end
    end

    context "on an address that does not belong to this order" do
      before do
        @order.bill_address_id = nil
        @order.ship_address = nil
      end

      it "cannot retreive address information" do
        api_get :show, :id => @address.id, :order_id => @order.number
        assert_unauthorized!
      end

      it "cannot update address information" do
        api_get :update, :id => @address.id, :order_id => @order.number
        assert_unauthorized!
      end
    end
  end
end
