require File.dirname(__FILE__) + '/../../spec_helper'

describe Admin::ShipmentsController do

  let(:shipment) { mock_model Shipment }
  let(:order) { mock_model(Order, :bill_address => nil) }

  before do
    controller.stub :current_user => nil
    Order.stub :find => order
    order.stub_chain :shipments, :find_by_permalink => shipment
    request.env["HTTP_REFERER"] = "http://localhost:3000"
  end

  context "#fire" do
    it "should fire the requested event on the payment" do
      shipment.should_receive(:foo).and_return true
      put :fire, {:order_id => "123", :id => "S456", :e => "foo"}
    end
    it "should respond with a flash message if the event cannot be fired" do
      shipment.stub :foo => false
      put :fire, {:order_id => "123", :id => "S456", :e => "foo"}
      flash[:error].should_not be_nil
    end
  end

end


