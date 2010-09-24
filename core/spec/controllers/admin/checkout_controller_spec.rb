require 'spec_helper'

describe Admin::CheckoutController do

  let(:order) { Order.create :checkout_allowed? => true, :complete? => false, :update_attributes => true, :payment? => false, :state => 'cart', :number => '123', :email => 'test@spree.com' }
  before do 
    Order.stub :find_by_number => order
    controller.stub :current_order => order
  end

  it "should understand checkout routes" do
    assert_routing("/admin/checkout", {:controller => "admin/checkout", :action => "edit"})
    assert_routing("/admin/checkout/cart", {:controller => "admin/checkout", :action => "edit", :state => 'cart'})
    assert_routing("/admin/checkout/update/cart", {:controller => "admin/checkout", :action => "update", :state => 'cart'})
  end


  context "#update" do
    context "save successful" do
      before { order.stub :update_attributes => true }

      it "should assign order" do
        put :update, {:state => "cart"}
        assigns[:order].should_not be_nil
      end

      context "when completed" do
        before { order.stub :completed? => true }
        it "should redirect to the order details" do
          put :update, {:state => "confirm"}
          response.should redirect_to admin_order_path(order)
        end
      end

      context "when incomplete" do
        before do
          order.stub :completed? => false, :shipment => mock_model(Shipment)
        end
        it "should redirect to the shipment details" do
          put :update, {:state => "cart"}
          response.should redirect_to admin_checkout_state_path(order.state)
        end
      end
    end

    context "save unsuccessful" do
      before do 
        order.stub :update_attributes => false
      end

      it "should render the checkout form" do
        put :update, {:state => "cart"}
        response.should render_template :edit
      end
    end

  end
end
