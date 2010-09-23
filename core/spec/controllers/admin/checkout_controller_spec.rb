require 'spec_helper'

describe Admin::CheckoutController do

  let(:order) { Order.create :checkout_allowed? => true, :complete? => false, :update_attributes => true, :payment? => false, :state => 'cart', :number => '123', :email => 'test@spree.com' }
  before do 
    Order.stub :find_by_number => order
    controller.stub :current_order => order
  end

  it "should understand checkout routes" do
    assert_routing("/admin/orders/123/checkout", {:controller => "admin/checkout", :action => "update", :order_number => "123", :method => :post})
    assert_routing("/admin/orders/123/checkout/cart", {:controller => "admin/checkout", :action => "edit", :order_number => "123", :state => "cart", :method => :get})
  end


  context "#update" do
    context "save successful" do
      before { order.stub :update_attributes => true }

      it "should assign order" do
        post :update, {:order_number => order.number, :method => :post}
        assigns[:order].should_not be_nil
      end

      context "when completed" do
        before { order.stub :completed? => true }
        it "should redirect to the order details" do
          post :update, {:order_number => order.number, :method => :post}
          response.should redirect_to admin_order_path(order)
        end
      end

      context "when incomplete" do
        before do
          order.stub :completed? => false, :shipment => mock_model(Shipment)
        end
        it "should redirect to the shipment details" do
          post :update, {:order_number => order.number, :method => :post}
          response.should redirect_to admin_orders_checkout_path(order.number, order.state)
        end
      end
    end

    context "save unsuccessful" do
      before do 
        order.stub :update_attributes => false
      end

      it "should render the checkout form" do
        post :update, {:order_number => order.number, :method => :post}
        response.should render_template :edit
      end
    end

  end
end
