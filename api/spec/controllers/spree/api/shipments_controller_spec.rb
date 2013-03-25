require 'spec_helper'

describe Spree::Api::ShipmentsController do
  render_views
  let!(:shipment) { create(:shipment) }
  let!(:attributes) { [:id, :tracking, :number, :cost, :shipped_at, :stock_location_name, :order_id, :shipping_rates, :shipping_method, :inventory_units] }

  before do
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
    let!(:order) { create(:completed_order_with_totals, shipments: [shipment]) }
    let!(:stock_location) { create(:stock_location_with_items) }
    let!(:variant) { create(:variant) }
    sign_in_as_admin!

    it 'can create a new shipment' do
      params = {
        variant_id: stock_location.stock_items.first.variant.to_param,
        order_id: order.number,
        stock_location_id: stock_location.to_param,
      }

      api_post :create, params
      response.status.should == 200
      json_response.should have_attributes(attributes)
    end

    it 'can update a shipment' do
      params = {
        shipment: {
          stock_location_id: stock_location.to_param
        }
      }

      api_put :update, params
      response.status.should == 200
      json_response['stock_location_name'].should == stock_location.name
    end

    it "can make a shipment ready" do
      Spree::Order.any_instance.stub(:paid? => true, :complete? => true)
      api_put :ready
      json_response.should have_attributes(attributes)
      json_response["state"].should == "ready"
      shipment.reload.state.should == "ready"
    end

    it "cannot make a shipment ready if the order is unpaid" do
      Spree::Order.any_instance.stub(:paid? => false)
      api_put :ready
      json_response["error"].should == "Cannot ready shipment."
      response.status.should == 422
    end

    it 'can add a variant to a shipment' do
      params = {
        order_id: order.number,
        id: order.shipments.first.to_param,
        variant_id: variant.to_param,
        quantity: 2
      }

      api_put :add, params
      response.status.should == 200
      json_response['inventory_units'][0]['variant_id'].should == variant.id
      json_response['inventory_units'].size.should == 2
    end

    it 'can remove a variant from a shipment' do
      order.shipments.first.add(variant, 2)

      params = {
        order_id: order.number,
        id: order.shipments.first.to_param,
        variant_id: variant.to_param,
        quantity: 1
      }

      api_put :remove, params
      response.status.should == 200
      json_response['inventory_units'][0]['variant_id'].should == variant.id
      json_response['inventory_units'].size.should == 1
    end

    context "can transition a shipment from ready to ship" do
      before do
        Spree::Order.any_instance.stub(:paid? => true, :complete? => true)
        shipment.update!(shipment.order)
        shipment.state.should == "ready"
      end

      it "can transition a shipment from ready to ship" do
        shipment.reload
        api_put :ship, :order_id => shipment.order.to_param, :id => shipment.to_param, :shipment => { :tracking => "123123" }
        json_response.should have_attributes(attributes)
        json_response["state"].should == "shipped"
      end
    end
  end
end
