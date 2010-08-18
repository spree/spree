require 'spec_helper'

describe OrdersController do

  let(:order) { mock_model(Order, :number => "R123", :reload => nil) }
  before { Order.stub(:find).with(1).and_return(order) }

  context "#populate" do
    before do
      Order.stub(:new).and_return(order)
      Order.stub(:create).and_return(order)
    end
    it "should create a new order when none specified" do
      Order.should_receive(:create).and_return order
      post :populate, {}, {}
      session[:order_id].should == order.id
    end
    it "should handle single variant/quantity pair" do
      variant = mock_model(Variant)
      Variant.should_receive(:find).and_return variant
      order.should_receive(:add_variant).with(variant, 2)
      post :populate, {:order_id => 1, :variants => {variant.id => 2}}
    end
    it "should handle multiple variant/quantity pairs"
  end

  context "#update" do
    before {
      order.stub(:update_attributes).and_return true
      Order.stub(:find_by_id).and_return(order)
    }
    it "should not result in a flash notice" do
      put :update, {}, {:order_id => 1}
      flash[:notice].should be_nil
    end
    it "should render the edit view" do
      put :update, {}, {:order_id => 1}
      response.should render_template :edit
    end
    it "should render the edit view (on failure)" do
      order.stub(:update_attributes).and_return false
      put :update, {}, {:order_id => 1}
      response.should render_template :edit
    end
  end

  context "#add variant" do
    it "should create a new line item (when appropriate)"
    it "should modify a line item (when appropriate)"
    it "should remove a line item (when appropriate)"
  end

  #TODO - move some of the assigns tests based on session, etc. into a shared example group once new block syntax released
end
