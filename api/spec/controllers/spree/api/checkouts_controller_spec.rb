require 'spec_helper'

module Spree
  describe Api::CheckoutsController do
    render_views

    before(:each) do
      stub_authentication!
      Spree::Config[:track_inventory_levels] = false
      country_zone = create(:zone, :name => 'CountryZone')
      @state = create(:state)
      @country = @state.country
      country_zone.members.create(:zoneable => @country)

      @shipping_method = create(:shipping_method, :zone => country_zone)
      @payment_method = create(:payment_method)
    end

    after do
      Spree::Config[:track_inventory_levels] = true
    end

    context "POST 'create'" do
      it "creates a new order when no parameters are passed" do
        api_post :create

        json_response['number'].should be_present
        response.status.should == 201
      end
    end

    context "PUT 'update'" do
      let(:order) { create(:order) }

      before(:each) do
        Order.any_instance.stub(:confirmation_required? => true)
        Order.any_instance.stub(:payment_required? => true)
      end

      it "will return an error if the order cannot transition" do
        order.update_column(:state, "address")
        api_put :update, :id => order.to_param
        json_response['error'].should =~ /could not be transitioned/
        response.status.should == 422
      end

      it "can update addresses and transition from address to delivery" do
        order.update_column(:state, "address")
        shipping_address = billing_address = {
          :firstname  => 'John',
          :lastname   => 'Doe',
          :address1   => '7735 Old Georgetown Road',
          :city       => 'Bethesda',
          :phone      => '3014445002',
          :zipcode    => '20814',
          :state_id   => @state.id,
          :country_id => @country.id
        }
        api_put :update,
                :id => order.to_param,
                :order => { :bill_address_attributes => billing_address, :ship_address_attributes => shipping_address }

        json_response['state'].should == 'delivery'
        json_response['bill_address']['firstname'].should == 'John'
        json_response['ship_address']['firstname'].should == 'John'
        response.status.should == 200
      end

      it "can update shipping method and transition from delivery to payment" do
        order.update_column(:state, "delivery")
        api_put :update, :id => order.to_param, :order => { :shipping_method_id => @shipping_method.id }

        json_response['shipments'][0]['shipping_method']['name'].should == @shipping_method.name
        json_response['state'].should == 'payment'
        response.status.should == 200
      end

      it "can transition from payment to confirm" do
        order.update_column(:state, "payment")
        api_put :update, :id => order.to_param
        json_response['state'].should == 'confirm'
        response.status.should == 200
      end

      it "can transition from confirm to complete" do
        order.update_column(:state, "confirm")
        Spree::Order.any_instance.stub(:payment_required? => false)
        api_put :update, :id => order.to_param
        json_response['state'].should == 'complete'
        response.status.should == 200
      end

      it "returns the order if the order is already complete" do
        order.update_column(:state, "complete")
        api_put :update, :id => order.to_param
        json_response['number'].should == order.number
        response.status.should == 200
      end
    end
  end
end
