require 'spec_helper'

describe Admin::CheckoutController do

  let(:order) { mock_model(Order, :checkout_allowed? => true, :complete? => false, :update_attributes => true, :payment? => false).as_null_object }
  before { Order.stub :find_by_number => order }

  it "should understand checkout routes" do
    assert_routing("/admin/orders/R123/checkout", {:controller => "admin/checkout", :action => "show", :number => "R123"})
    assert_routing("/admin/orders/R123/checkout/edit", {:controller => "admin/checkout", :action => "edit", :number => "R123"})
  end


  context "#update" do
    context "save successful" do
      before { order.stub :update_attributes => true }

      it "should assign order" do
        put :update, {:number => "123"}
        assigns[:order].should_not be_nil
      end

      context "when completed" do
        before { order.stub :completed? => true }
        it "should redirect to the checkout details" do
          put :update, {:number => "123"}
          response.should redirect_to admin_checkout_path(order)
        end
      end

      context "when incomplete" do
        before do
          order.stub :completed? => false, :shipment => mock_model(Shipment)
        end
        it "should redirect to the shipment details" do
          put :update, {:number => "123"}
          response.should redirect_to edit_admin_order_shipment_url(order, order.shipment)
        end
      end
    end

    context "save unsuccessful" do
      before { order.stub :update_attributes => false }

      it "should render the checkout form" do
        put :update, {:number => "123"}
        response.should render_template :edit
      end
    end

  end
end
