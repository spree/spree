require 'spec_helper'

describe Admin::PaymentsController do

  let(:order) { mock_model(Order, :complete? => true).as_null_object }
  let(:payment) { mock_model(Payment).as_null_object }

  before do
    controller.stub :current_user => nil
    Order.stub :find => order
    Payment.stub :find => payment
  end

  context "#fire" do
    it "should fire the requested event on the payment" do
      payment.should_receive(:foo).and_return true
      put :fire, {:order_id => "123", :id => "456", :e => "foo"}
    end
    it "should respond with a flash message if the event cannot be fired" do
      payment.stub :foo => false
      put :fire, {:order_id => "123", :id => "456", :e => "foo"}
      flash[:error].should_not be_nil
    end
  end

end