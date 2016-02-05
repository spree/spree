require 'spec_helper'

describe Spree::CheckoutController, type: :controller do
  let(:token) { 'some_token' }
  let(:user) { stub_model(Spree::LegacyUser) }
  let(:order) { FactoryGirl.create(:order_with_totals) }

  let(:address_params) do
    address = FactoryGirl.build(:address)
    address.attributes.except("created_at", "updated_at")
  end

  before do
    allow(controller).to receive_messages try_spree_current_user: user
    allow(controller).to receive_messages spree_current_user: user
    allow(controller).to receive_messages current_order: order
  end

  context "#edit" do
    it 'should check if the user is authorized for :edit' do
      expect(controller).to receive(:authorize!).with(:edit, order, token)
      request.cookie_jar.signed[:guest_token] = token
      spree_get :edit, state: 'address'
    end

    it "should redirect to the cart path unless checkout_allowed?" do
      allow(order).to receive_messages checkout_allowed?: false
      spree_get :edit, state: "delivery"
      expect(response).to redirect_to(spree.cart_path)
    end

    it "should redirect to the cart path if current_order is nil" do
      allow(controller).to receive(:current_order).and_return(nil)
      spree_get :edit, state: "delivery"
      expect(response).to redirect_to(spree.cart_path)
    end

    it "should redirect to cart if order is completed" do
      allow(order).to receive_messages(completed?: true)
      spree_get :edit, state: "address"
      expect(response).to redirect_to(spree.cart_path)
    end

    # Regression test for #2280
    it "should redirect to current step trying to access a future step" do
      order.update_column(:state, "address")
      spree_get :edit, state: "delivery"
      expect(response).to redirect_to spree.checkout_state_path("address")
    end

    context "when entering the checkout" do
      before do
        # The first step for checkout controller is address
        # Transitioning into this state first is required
        order.update_column(:state, "address")
      end

      it "should associate the order with a user" do
        order.update_column :user_id, nil
        expect(order).to receive(:associate_user!).with(user)
        spree_get :edit, {}, order_id: 1
      end
    end
  end

  context "#update" do
    it 'should check if the user is authorized for :edit' do
      expect(controller).to receive(:authorize!).with(:edit, order, token)
      request.cookie_jar.signed[:guest_token] = token
      spree_post :update, state: 'address'
    end

    context "save successful" do
      def spree_post_address
        spree_post :update,
                   state: "address",
                   order: {
                     bill_address_attributes: address_params,
                     use_billing: true
                   }
      end

      before do
        # Must have *a* shipping method and a payment method so updating from address works
        allow(order).to receive(:available_shipping_methods).
          and_return [stub_model(Spree::ShippingMethod)]
        allow(order).to receive(:available_payment_methods).
          and_return [stub_model(Spree::PaymentMethod)]
        allow(order).to receive(:ensure_available_shipping_rates).
          and_return true
        order.line_items << FactoryGirl.create(:line_item)
      end

      context "with the order in the cart state" do
        before do
          order.update_column(:state, "cart")
          allow(order).to receive_messages user: user
        end

        it "should assign order" do
          spree_post :update, state: "address"
          expect(assigns[:order]).not_to be_nil
        end

        it "should advance the state" do
          spree_post_address
          expect(order.reload.state).to eq("delivery")
        end

        it "should redirect the next state" do
          spree_post_address
          expect(response).to redirect_to spree.checkout_state_path("delivery")
        end

        context "current_user respond to save address method" do
          it "calls persist order address on user" do
            expect(user).to receive(:persist_order_address)
            spree_post :update,
                       state: "address",
                       order: {
                         bill_address_attributes: address_params,
                         use_billing: true
                       },
                       save_user_address: "1"
          end
        end

        context "current_user doesnt respond to persist_order_address" do
          it "doesnt raise any error" do
            expect do
              spree_post :update,
                         state: "address",
                         order: {
                           bill_address_attributes: address_params,
                           use_billing: true
                         },
                         save_user_address: "1"
            end.to_not raise_error
          end
        end
      end

      context "with the order in the address state" do
        before do
          order.update_columns(ship_address_id: create(:address).id, state: "address")
          allow(order).to receive_messages user: user
        end

        context "with a billing and shipping address" do
          let(:bill_address_params) do
            order.bill_address.attributes.except("created_at", "updated_at")
          end
          let(:ship_address_params) do
            order.ship_address.attributes.except("created_at", "updated_at")
          end
          let(:update_params) do
            {
              state: "address",
              order: {
                bill_address_attributes: bill_address_params,
                ship_address_attributes: ship_address_params,
                use_billing: false
              }
            }
          end

          before do
            @expected_bill_address_id = order.bill_address.id
            @expected_ship_address_id = order.ship_address.id

            spree_post :update, update_params
            order.reload
          end

          it "updates the same billing and shipping address" do
            expect(order.bill_address.id).to eq(@expected_bill_address_id)
            expect(order.ship_address.id).to eq(@expected_ship_address_id)
          end
        end
      end

      context "when in the confirm state" do
        before do
          allow(order).to receive_messages confirmation_required?: true
          order.update_column(:state, "confirm")
          allow(order).to receive_messages user: user
          # An order requires a payment to reach the complete state
          # This is because payment_required? is true on the order
          create(:payment, amount: order.total, order: order)
          order.payments.reload
        end

        # This inadvertently is a regression test for #2694
        it "should redirect to the order view" do
          spree_post :update, state: "confirm"
          expect(response).to redirect_to spree.order_path(order)
        end

        it "should populate the flash message" do
          spree_post :update, state: "confirm"
          expect(flash.notice).to eq(Spree.t(:order_processed_successfully))
        end

        it "should remove completed order from current_order" do
          spree_post :update, { state: "confirm" }, order_id: "foofah"
          expect(assigns(:current_order)).to be_nil
          expect(assigns(:order)).to eql controller.current_order
        end
      end

      # Regression test for #4190
      context "state_lock_version" do
        let(:post_params) do
          {
            state: "address",
            order: {
              bill_address_attributes: order.bill_address.attributes.except("created_at", "updated_at"),
              state_lock_version: 0,
              use_billing: true
            }
          }
        end

        context "correct" do
          it "should properly update and increment version" do
            spree_post :update, post_params
            expect(order.state_lock_version).to eq 1
          end
        end

        context "incorrect" do
          before do
            order.update_columns(state_lock_version: 1, state: "address")
          end

          it "order should receieve ensure_valid_order_version callback" do
            expect_any_instance_of(described_class).to receive(:ensure_valid_state_lock_version)
            spree_post :update, post_params
          end

          it "order should receieve with_lock message" do
            expect(order).to receive(:with_lock)
            spree_post :update, post_params
          end

          it "redirects back to current state" do
            spree_post :update, post_params
            expect(response).to redirect_to spree.checkout_state_path('address')
            expect(flash[:error]).to eq "The order has already been updated."
          end
        end
      end
    end

    context "save unsuccessful" do
      before do
        allow(order).to receive_messages user: user
        allow(order).to receive_messages update_attributes: false
      end

      it "should not assign order" do
        spree_post :update, state: "address"
        expect(assigns[:order]).not_to be_nil
      end

      it "should not change the order state" do
        spree_post :update, state: 'address'
      end

      it "should render the edit template" do
        spree_post :update, state: 'address'
        expect(response).to render_template :edit
      end
    end

    context "when current_order is nil" do
      before { allow(controller).to receive_messages current_order: nil }

      it "should not change the state if order is completed" do
        expect(order).not_to receive(:update_attribute)
        spree_post :update, state: "confirm"
      end

      it "should redirect to the cart_path" do
        spree_post :update, state: "confirm"
        expect(response).to redirect_to spree.cart_path
      end
    end

    context "Spree::Core::GatewayError" do
      before do
        allow(order).to receive_messages user: user
        allow(order).to receive(:update_attributes).and_raise(Spree::Core::GatewayError.new("Invalid something or other."))
        spree_post :update, state: "address"
      end

      it "should render the edit template and display exception message" do
        expect(response).to render_template :edit
        expect(flash.now[:error]).to eq(Spree.t(:spree_gateway_error_flash_for_checkout))
        expect(assigns(:order).errors[:base]).to include("Invalid something or other.")
      end
    end

    context "fails to transition from address" do
      let(:order) do
        FactoryGirl.create(:order_with_line_items).tap do |order|
          order.next!
          expect(order.state).to eq('address')
        end
      end

      before do
        allow(controller).to receive_messages current_order: order
        allow(controller).to receive_messages check_authorization: true
      end

      context "when the country is not a shippable country" do
        before do
          order.ship_address.tap do |address|
            # A different country which is not included in the list of shippable countries
            address.country = FactoryGirl.create(:country, name: "Australia")
            address.state_name = 'Victoria'
            address.save
          end
        end

        it "due to no available shipping rates for any of the shipments" do
          expect(order.shipments.count).to eq(1)
          order.shipments.first.shipping_rates.delete_all

          spree_put :update, state: order.state, order: {}
          expect(flash[:error]).to eq(Spree.t(:items_cannot_be_shipped))
          expect(response).to redirect_to(spree.checkout_state_path('address'))
        end
      end

      context "when the order is invalid" do
        before do
          allow(order).to receive_messages(update_from_params: true, next: nil)
          order.errors.add(:base, 'Base error')
          order.errors.add(:adjustments, 'error')
        end

        it "due to the order having errors" do
          spree_put :update, state: order.state, order: {}
          expect(flash[:error]).to eql("Base error\nAdjustments error")
          expect(response).to redirect_to(spree.checkout_state_path('address'))
        end
      end
    end

    context "fails to transition from payment to complete" do
      let(:order) do
        FactoryGirl.create(:order_with_line_items).tap do |order|
          until order.state == 'payment'
            order.next!
          end
          # So that the confirmation step is skipped and we get straight to the action.
          payment_method = FactoryGirl.create(:simple_credit_card_payment_method)
          payment = FactoryGirl.create(:payment, payment_method: payment_method)
          order.payments << payment
        end
      end

      before do
        allow(controller).to receive_messages current_order: order
        allow(controller).to receive_messages check_authorization: true
      end

      it "when GatewayError is raised" do
        allow_any_instance_of(Spree::Payment).to receive(:process!).and_raise(Spree::Core::GatewayError.new(Spree.t(:payment_processing_failed)))
        spree_put :update, state: order.state, order: {}
        expect(flash[:error]).to eq(Spree.t(:payment_processing_failed))
      end
    end
  end

  context "When last inventory item has been purchased" do
    let(:product) { mock_model(Spree::Product, name: "Amazing Object") }
    let(:variant) { mock_model(Spree::Variant) }
    let(:line_item) { mock_model Spree::LineItem, insufficient_stock?: true, amount: 0 }
    let(:order) { create(:order) }

    before do
      allow(order).to receive_messages(line_items: [line_item], state: "payment")

      configure_spree_preferences do |config|
        config.track_inventory_levels = true
      end
    end

    context "and back orders are not allowed" do
      before do
        spree_post :update, state: "payment"
      end

      it "should redirect to cart" do
        expect(response).to redirect_to spree.cart_path
      end

      it "should set flash message for no inventory" do
        expect(flash[:error]).to eq(
          Spree.t(:inventory_error_flash_for_insufficient_quantity, names: "'#{product.name}'"))
      end
    end
  end

  context "order doesn't have a delivery step" do
    before do
      allow(order).to receive_messages(checkout_steps: ["cart", "address", "payment"])
      allow(order).to receive_messages state: "address"
      allow(controller).to receive_messages check_authorization: true
    end

    it "doesn't set shipping address on the order" do
      expect(order).to_not receive(:ship_address=)
      spree_post :update, state: order.state
    end

    it "doesn't remove unshippable items before payment" do
      expect { spree_post :update, state: "payment" }.
        to_not change { order.line_items }
    end
  end

  it "does remove unshippable items before payment" do
    allow(order).to receive_messages payment_required?: true
    allow(controller).to receive_messages check_authorization: true

    expect { spree_post :update, state: "payment" }.
      to change { order.reload.line_items.length }
  end

  context 'in the payment step' do
    let(:order) { OrderWalkthrough.up_to(:payment) }
    let(:payment_method_id) { Spree::PaymentMethod.first.id }

    before do
      expect(order.state).to eq 'payment'
      allow(order).to receive_messages user: user
      allow(order).to receive_messages confirmation_required?: true
    end

    it 'does not advance the order extra even when called twice' do
      spree_put :update, state: 'payment',
                         order: { payments_attributes: [{ payment_method_id: payment_method_id }] }
      order.reload
      expect(order.state).to eq 'confirm'
      spree_put :update, state: 'payment',
                         order: { payments_attributes: [{ payment_method_id: payment_method_id }] }
      order.reload
      expect(order.state).to eq 'confirm'
    end
  end
end
