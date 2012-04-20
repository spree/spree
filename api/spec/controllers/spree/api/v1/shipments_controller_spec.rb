require 'spec_helper'

describe Spree::Api::V1::ShipmentsController do
  let!(:shipment) { Factory(:shipment) }
  let!(:attributes) { [:id, :tracking, :number, :cost, :shipped_at] }

  before do
    shipment.order.payment_state == 'paid'
    stub_authentication!
  end

  context "working with a shipment" do
    let!(:resource_scoping) { { :order_id => shipment.order.to_param, :id => shipment.to_param } }

    it "can make a shipment ready" do
      api_put :ready
      json_response.should have_attributes(attributes)
      json_response["shipment"]["state"].should == "ready"
    end

    context "can transition a shipment from ready to ship" do
      before do
        shipment.order.update_attribute(:payment_state, 'paid')
        shipment.update!(shipment.order)
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
