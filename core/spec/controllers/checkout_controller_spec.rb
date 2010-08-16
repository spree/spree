require 'spec_helper'

describe CheckoutController do

  let(:order) { mock_model Order, :complete? => false, :empty? => false, :state => "confirm", :state= => nil, :can_next? => true,
                                  :payment? => false, :next! => true, :bill_address => mock_model(Address), :ship_address => mock_model(Address) }
  before { Order.stub!(:find_by_id).and_return order }

  it "should understand checkout routes" do
    assert_routing("/checkout/delivery", {:controller => "checkout", :action => "edit", :state => "delivery"})
    assert_routing("/checkout/update/delivery", {:controller => "checkout", :action => "update", :state => "delivery"})
  end

  context "#edit" do

    it "should redirect to the order_path if order.complete?" do
      order.stub(:complete?).and_return true
      get :edit, { :state => "delivery" }
      response.should redirect_to order_path(assigns[:order])
    end

    it "should change to the requested state" do
      order.should_receive(:state=).with("payment").and_return true
      get :edit, { :state => "payment" }
    end

  end

  context "#update" do

    it "should remove completed order from the session" do
      order.stub(:complete?).and_return(true)
      post :update, {:state => "confirm"}, {:order_id => "foo"}
      session[:order_id].should be_nil
    end

    context "save successful" do
      before do
        order.stub(:update_attribute).and_return true
        order.should_receive(:update_attributes).and_return true
      end

      it "should assign order" do
        post :update, {:state => "confirm"}
        assigns[:order].should_not be_nil
      end

      it "should change to requested state" do
        order.should_receive(:update_attribute).with('state', 'confirm')
        post :update, {:state => "confirm"}
      end

      context "with next state" do
        before { order.stub(:state).and_return("complete") }

        it "should advance the state" do
          order.should_receive(:next!).and_return true
          post :update, {:state => "confirm"}
        end

        it "should redirect the next state" do
          post :update, {:state => "confirm"}
          response.should redirect_to checkout_state_path("complete")
        end
      end

      context "with no more steps (would only happen on refresh)" do
        before { order.stub(:can_next?).and_return false }

        it "should not advance the next state" do
          order.should_not_receive(:next!)
          post :update, {:state => "confirm"}
        end

        it "should render the current state" do
          post :update, {:state => "confirm"}
          response.should render_template :edit
        end
      end
    end

    context "save unsuccessful" do
      before { order.should_receive(:update_attributes).and_return false }

      it "should assign order" do
        post :update, {:state => "confirm"}
        assigns[:order].should_not be_nil
      end

      it "should not change the order state" do
        order.should_not_receive(:update_attribute)
        post :update, { :state => 'confirm' }
      end

      it "should render the edit template" do
        post :update, { :state => 'confirm' }
        response.should render_template :edit
      end
    end

    context "when order is complete" do
      before(:each) { order.stub(:complete?).and_return true }

      it "should not change the state if order is completed" do
        order.should_not_receive(:update_attribute)
        post :update, {:state => "confirm"}
      end

      it "should redirect to the order_path" do
        post :update, {:state => "confirm"}
        response.should redirect_to order_path(assigns[:order])
      end
    end

  end
end