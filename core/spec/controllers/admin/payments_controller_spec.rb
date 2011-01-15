require File.dirname(__FILE__) + '/../../spec_helper'

describe Admin::PaymentsController do

  let(:order) { mock_model(Order, :complete? => true, :total => 100) }
  let(:creditcard) { mock_model(Creditcard) }
  let(:payment) { mock_model(Payment, :payment_method => nil, :payment_source => creditcard) }

  before do
    controller.stub :current_user => nil
    Order.stub :find => order
    order.stub_chain :creditcards, :with_payment_profile => []
    Payment.stub :find => payment
  end

  context "#fire" do
    it "should fire the requested event on the payment" do
      creditcard.should_receive(:foo).and_return true
      put :fire, {:order_id => "123", :id => "456", :e => "foo"}
    end
    it "should respond with a flash message if the event cannot be fired" do
      creditcard.stub :foo => false
      put :fire, {:order_id => "123", :id => "456", :e => "foo"}
      flash[:error].should_not be_nil
    end
  end

end
