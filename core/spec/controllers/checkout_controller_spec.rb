require File.dirname(__FILE__) + '/../spec_helper'

describe CheckoutController do
  let(:order) { mock_model(Order, :checkout_allowed? => true, :completed? => false, :update_attributes => true, :payment? => false).as_null_object }
  before { controller.stub :current_order => order }

  it "should understand checkout routes" do
    assert_routing("/checkout/delivery", {:controller => "checkout", :action => "edit", :state => "delivery"})
    assert_routing("/checkout/update/delivery", {:controller => "checkout", :action => "update", :state => "delivery"})
  end

  context "#edit" do

    it "should redirect to the cart path unless checkout_allowed?" do
      order.stub :checkout_allowed? => false
      get :edit, { :state => "delivery" }
      response.should redirect_to cart_path
    end

    it "should redirect to the cart path if current_order is nil" do
      controller.stub!(:current_order).and_return(nil)
      get :edit, { :state => "delivery" }
      response.should redirect_to cart_path
    end

    it "should change to the requested state" do
      order.should_receive(:state=).with("payment").and_return true
      get :edit, { :state => "payment" }
    end

    it "should redirect to cart if order is completed" do
      order.stub(:completed? => true)
      get :edit, {:state => "address"}
      response.should redirect_to(cart_path)
    end

  end

  context "#update" do

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
        order.should_receive(:state=).with('confirm')
        post :update, {:state => "confirm"}
      end

      context "with next state" do
        before { order.stub :next => true }

        it "should advance the state" do
          order.should_receive(:next).and_return true
          post :update, {:state => "delivery"}
        end

        it "should redirect the next state" do
          order.stub :state => "payment"
          post :update, {:state => "delivery"}
          response.should redirect_to checkout_state_path("payment")
        end

        context "when in the confirm state" do
          before { order.stub :state => "complete" }

          it "should redirect to the order view" do
            post :update, {:state => "confirm"}
            response.should redirect_to order_path(order)
          end

          it "should populate the flash message" do
            post :update, {:state => "confirm"}
            flash[:notice].should == I18n.t(:order_processed_successfully)
          end

          it "should remove completed order from the session" do
            post :update, {:state => "confirm"}, {:order_id => "foofah"}
            session[:order_id].should be_nil
          end

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

    context "when current_order is nil" do
      before { controller.stub! :current_order => nil }
      it "should not change the state if order is completed" do
        order.should_not_receive(:update_attribute)
        post :update, {:state => "confirm"}
      end

      it "should redirect to the cart_path" do
        post :update, {:state => "confirm"}
        response.should redirect_to cart_path
      end
    end

    context "Spree::GatewayError" do

      before do
        order.stub(:update_attributes).and_raise(Spree::GatewayError)
        post :update, {:state => "whatever"}
      end

      it "should render the edit template" do
        response.should render_template :edit
      end

      it "should set appropriate flash message" do
        flash[:error].should == I18n.t('spree_gateway_error_flash_for_checkout')
      end

    end

  end
end
