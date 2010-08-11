require 'spec_helper'

describe OrdersController do

  let(:order) { mock_model(Order, :number => "R123") }
  before { Order.stub(:find).with(1).and_return(order) }

  context "#populate" do
    before do
      Order.stub(:new).and_return(order)
      Order.stub(:create).and_return(order)
    end
    it "should use the order indicated by the parameter (if it exists)" do
      Order.should_receive(:find_by_number).and_return order
      Order.should_not_receive(:create)
      post :populate, {:id => order.number}, {}
      assigns[:order].should == order
    end
    it "should return 404 (if the param order cannot be found)" do
      Order.should_receive(:find_by_number).and_return nil
      post :populate, {:id => 123}, {}
      response.should render_template("#{Rails.root}/public/404.html")
    end
    it "should use the order in the session (if it exists)" do
      Order.should_receive(:find_by_id).and_return order
      Order.should_not_receive(:create)
      post :populate, {}, {:order_id => 123}
      assigns[:order].should == order
    end
    it "should return 404 (if the session order cannot be found)" do
      Order.should_receive(:find_by_id).and_return nil
      post :populate, {}, {:order_id => 123}
      response.should render_template("#{Rails.root}/public/404.html")
    end
    it "should create a new order when none specified" do
      Order.should_receive(:create).and_return order
      post :populate, {}, {}
      session[:order_id].should == order.id
    end
    it "should handle single variant/quantity pair" do
      variant = mock_model(Variant)
      Variant.should_receive(:find).and_return variant
      order.should_receive(:add_variant).with(variant, :quantity)
      post :populate, {:order_id => 1, :variants => {:variant_id => :quantity}}
    end
    it "should handle multiple variant/quantity pairs"
  end

  context "#add variant" do
    it "should create a new line item (when appropriate)"
    it "should modify a line item (when appropriate)"
    it "should remove a line item (when appropriate)"
  end

  #TODO - move some of the assigns tests based on session, etc. into a shared example group once new block syntax released
end