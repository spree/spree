require 'spec_helper'

describe Spree::Admin::OrdersController do

  let(:order) { mock_model(Spree::Order, :complete? => true, :total => 100) }

  before do
    Spree::Order.stub :find_by_number => order
    request.env["HTTP_REFERER"] = "http://localhost:3000"
  end

  context "#fire" do
    it "should fire the requested event on the payment" do
      order.should_receive(:foo).and_return true
      spree_put :fire, {:id => "R1234567", :e => "foo"}
    end
    it "should respond with a flash message if the event cannot be fired" do
      order.stub :foo => false
      spree_put :fire, {:id => "R1234567", :e => "foo"}
      flash[:error].should_not be_nil
    end
  end

end
