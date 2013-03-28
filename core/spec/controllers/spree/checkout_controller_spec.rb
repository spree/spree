require 'spec_helper'

describe Spree::CheckoutController do
  let(:token) { 'some_token' }
  let(:user) { stub_model(Spree::LegacyUser) }
  let(:order) do
    order = FactoryGirl.create(:order_with_totals)
  end

  before do
    controller.stub :try_spree_current_user => user
    controller.stub :current_order => order
  end

  context "#edit" do

    it 'should check if the user is authorized for :edit' do
      controller.should_receive(:authorize!).with(:edit, order, token)
      spree_get :edit, { :state => 'address' }, { :access_token => token }
    end

    it "should redirect to the cart path unless checkout_allowed?" do
      order.stub :checkout_allowed? => false
      spree_get :edit, { :state => "delivery" }
      response.should redirect_to(spree.cart_path)
    end

    it "should redirect to the cart path if current_order is nil" do
      controller.stub!(:current_order).and_return(nil)
      spree_get :edit, { :state => "delivery" }
      response.should redirect_to(spree.cart_path)
    end

    it "should redirect to cart if order is completed" do
      order.stub(:completed? => true)
      spree_get :edit, {:state => "address"}
      response.should redirect_to(spree.cart_path)
    end

    context "when entering the checkout" do
      before do
        # The first step for checkout controller is address
        # Transitioning into this state first is required
        order.update_column(:state, "address")
      end

      it "should associate the order with a user" do
        order.user = nil
        order.should_receive(:associate_user!).with(user)
        spree_get :edit, {}, :order_id => 1
      end

      it "should fire the spree.user.signup event if user has just signed up" do
        controller.should_receive(:fire_event).with("spree.user.signup", :user => user, :order => order)
        spree_get :edit, {}, :spree_user_signup => true
      end
    end
  end

  context "#update" do

    it 'should check if the user is authorized for :edit' do
      controller.should_receive(:authorize!).with(:edit, order, token)
      spree_post :update, { :state => 'address' }, { :access_token => token }
    end

    context "save successful" do
      context "with the order in the cart state" do
        before do
          order.update_column(:state, "cart")
          order.stub :user => user

          # Must have *a* shipping method and a payment method so updating from address works
          order.stub :available_shipping_methods => [stub_model(Spree::ShippingMethod)]
          order.stub :available_payment_methods => [stub_model(Spree::PaymentMethod)]
        end

        let(:address_params) do
          address = FactoryGirl.build(:address)
          address.attributes.except("created_at", "updated_at")
        end

        it "should assign order" do
          spree_post :update, {:state => "address"}
          assigns[:order].should_not be_nil
        end

        it "should advance the state" do
          spree_post :update, {
            :state => "address",
            :order => {
              :bill_address_attributes => address_params,
              :use_billing => true
            }
          }
          order.reload.state.should == "delivery"
        end

        it "should redirect the next state" do
          spree_post :update, {
            :state => "address",
            :order => {
              :bill_address_attributes => address_params,
              :use_billing => true
            }
          }
          response.should redirect_to spree.checkout_state_path("delivery")
        end
      end

      context "when in the confirm state" do
        before do
          order.stub :confirmation_required? => true
          order.update_column(:state, "confirm")
          order.stub :user => user
          # An order requires a payment to reach the complete state
          # This is because payment_required? is true on the order
          create(:payment, :amount => order.total, :order => order)
          order.payments.reload
        end

        # This inadvertently is a regression test for #2694
        it "should redirect to the order view" do
          spree_post :update, {:state => "confirm"}
          response.should redirect_to spree.order_path(order)
        end

        it "should populate the flash message" do
          spree_post :update, {:state => "confirm"}
          flash.notice.should == I18n.t(:order_processed_successfully)
        end

        it "should remove completed order from the session" do
          spree_post :update, {:state => "confirm"}, {:order_id => "foofah"}
          session[:order_id].should be_nil
        end
      end
    end

    context "save unsuccessful" do
      before do
        order.stub :user => user
        order.stub :update_attributes => false
      end

      it "should not assign order" do
        spree_post :update, {:state => "address"}
        assigns[:order].should_not be_nil
      end

      it "should not change the order state" do
        spree_post :update, { :state => 'address' }
      end

      it "should render the edit template" do
        spree_post :update, { :state => 'address' }
        response.should render_template :edit
      end
    end

    context "when current_order is nil" do
      before { controller.stub! :current_order => nil }
      it "should not change the state if order is completed" do
        order.should_not_receive(:update_attribute)
        spree_post :update, {:state => "confirm"}
      end

      it "should redirect to the cart_path" do
        spree_post :update, {:state => "confirm"}
        response.should redirect_to spree.cart_path
      end
    end

    context "Spree::Core::GatewayError" do

      before do
        order.stub :user => user
        order.stub(:update_attributes).and_raise(Spree::Core::GatewayError)
        spree_post :update, {:state => "address"}
      end

      it "should render the edit template" do
        response.should render_template :edit
        flash[:error].should == I18n.t(:spree_gateway_error_flash_for_checkout)
      end
    end

  end

  context "When last inventory item has been purchased" do
    let(:product) { mock_model(Spree::Product, :name => "Amazing Object") }
    let(:variant) { mock_model(Spree::Variant, :on_hand => 0) }
    let(:line_item) { mock_model Spree::LineItem, :insufficient_stock? => true }
    let(:order) { create(:order) }

    before do
      order.stub(:line_items => [line_item])

      configure_spree_preferences do |config|
        config.track_inventory_levels = true
        config.allow_backorders = false
      end

    end

    context "and back orders == false" do
      before do
        spree_post :update, {:state => "payment"}
      end

      it "should render edit template" do
        response.should redirect_to spree.cart_path
      end

      it "should set flash message for no inventory" do
        flash[:error].should == I18n.t(:spree_inventory_error_flash_for_insufficient_quantity , :names => "'#{product.name}'" )
      end

    end

  end

end
