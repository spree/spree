require 'spec_helper'

describe Spree::Api::ShipmentsController do
  render_views
  let!(:shipment) { create(:shipment) }
  let!(:attributes) { [:id, :tracking, :number, :cost, :shipped_at] }

  before do
    Spree::Order.any_instance.stub(:paid? => true, :complete? => true)
    stub_authentication!
  end

  let!(:resource_scoping) { { :order_id => shipment.order.to_param, :id => shipment.to_param } }

  context "as a non-admin" do
    it "cannot make a shipment ready" do
      api_put :ready
      assert_unauthorized!
    end

    it "cannot make a shipment shipped" do
      api_put :ship
      assert_unauthorized!
    end
  end

  context "as an admin" do
    sign_in_as_admin!

    it "can make a shipment ready" do
      api_put :ready
      json_response.should have_attributes(attributes)
      json_response["shipment"]["state"].should == "ready"
      shipment.reload.state.should == "ready"
    end

    context "can transition a shipment from ready to ship" do
      before do
        shipment.update!(shipment.order)
        shipment.state.should == "ready"
      end

      it "can transition a shipment from ready to ship" do
        shipment.reload
        api_put :ship, :order_id => shipment.order.to_param, :id => shipment.to_param, :shipment => { :tracking => "123123" }
        json_response.should have_attributes(attributes)
        json_response["shipment"]["state"].should == "shipped"
      end
    end
  end
end
