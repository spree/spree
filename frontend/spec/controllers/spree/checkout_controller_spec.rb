require 'spec_helper'

describe Spree::CheckoutController, type: :controller do
  let(:token) { 'some_token' }
  let(:user) { stub_model(Spree::LegacyUser) }
  let(:order) { FactoryBot.create(:order_with_totals) }

  let(:address_params) do
    address = FactoryBot.build(:address)
    address.attributes.except('created_at', 'updated_at')
  end

  before do
    allow(controller).to receive_messages try_spree_current_user: user
    allow(controller).to receive_messages spree_current_user: user
    allow(controller).to receive_messages current_order: order
  end

  context '#edit' do
    it 'checks if the user is authorized for :edit' do
      expect(controller).to receive(:authorize!).with(:edit, order, token)
      request.cookie_jar.signed[:token] = token
      get :edit, params: { state: 'address' }
    end

    it 'redirects to the cart path unless checkout_allowed?' do
      allow(order).to receive_messages checkout_allowed?: false
      get :edit, params: { state: 'delivery' }
      expect(response).to redirect_to(spree.cart_path)
    end

    it 'redirects to the cart path if current_order is nil' do
      allow(controller).to receive(:current_order).and_return(nil)
      get :edit, params: { state: 'delivery' }
      expect(response).to redirect_to(spree.cart_path)
    end

    it 'redirects to cart if order is completed' do
      allow(order).to receive_messages(completed?: true)
      get :edit, params: { state: 'address' }
      expect(response).to redirect_to(spree.cart_path)
    end

    # Regression test for #2280
    it 'redirects to current step trying to access a future step' do
      order.update_column(:state, 'address')
      get :edit, params: { state: 'delivery' }
      expect(response).to redirect_to spree.checkout_state_path('address')
    end

    context 'when entering the checkout' do
      before do
        # The first step for checkout controller is address
        # Transitioning into this state first is required
        order.update_column(:state, 'address')
      end

      it 'associates the order with a user' do
        order.update_column :user_id, nil
        expect(order).to receive(:associate_user!).with(user)
        get :edit, params: { order_id: 1 }
      end
    end
  end

  context '#update' do
    it 'checks if the user is authorized for :edit' do
      expect(controller).to receive(:authorize!).with(:edit, order, token)
      request.cookie_jar.signed[:token] = token
      post :update, params: { state: 'address' }
    end

    context 'save successful' do
      def spree_post_address
        post :update, params: {
                   state: 'address',
                   order: {
                     bill_address_attributes: address_params,
                     use_billing: true
                   }
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
        order.line_items << FactoryBot.create(:line_item)
      end

      context 'with the order in the cart state' do
        before do
          order.update_column(:state, 'cart')
          allow(order).to receive_messages user: user
        end

        it 'assigns order' do
          post :update, params: { state: 'address' }
          expect(assigns[:order]).not_to be_nil
        end

        it 'advances the state' do
          spree_post_address
          expect(order.reload.state).to eq('delivery')
        end

        it 'redirects the next state' do
          spree_post_address
          expect(response).to redirect_to spree.checkout_state_path('delivery')
        end
      end

      context 'with the order in the address state' do
        before do
          order.update_columns(ship_address_id: create(:address).id, state: 'address')
          allow(order).to receive_messages user: user
        end

        context 'with a billing and shipping address' do
          let(:bill_address_params) do
            order.bill_address.attributes.except('created_at', 'updated_at')
          end
          let(:ship_address_params) do
            order.ship_address.attributes.except('created_at', 'updated_at')
          end
          let(:update_params) do
            {
              state: 'address',
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

            post :update, params: update_params
            order.reload
          end

          it 'updates the same billing and shipping address' do
            expect(order.bill_address.id).to eq(@expected_bill_address_id)
            expect(order.ship_address.id).to eq(@expected_ship_address_id)
          end
        end
      end

      context 'when in the confirm state' do
        before do
          allow(order).to receive_messages confirmation_required?: true
          order.update_column(:state, 'confirm')
          allow(order).to receive_messages user: user
          # An order requires a payment to reach the complete state
          # This is because payment_required? is true on the order
          create(:payment, amount: order.total, order: order)
          order.payments.reload
        end

        # This inadvertently is a regression test for #2694
        it 'redirects to the order view' do
          post :update, params: { state: 'confirm' }
          expect(response).to redirect_to spree.order_path(order)
        end

        it 'populates the flash message' do
          post :update, params: { state: 'confirm' }
          expect(flash.notice).to eq(Spree.t(:order_processed_successfully))
        end

        it 'removes completed order from current_order' do
          post :update, params: { state: 'confirm', order_id: 'foofah' }
          expect(assigns(:current_order)).to be_nil
          expect(assigns(:order)).to eql controller.current_order
        end
      end

      # Regression test for #4190
      context 'state_lock_version' do
        let(:post_params) do
          {
            state: 'address',
            order: {
              bill_address_attributes: order.bill_address.attributes.except('created_at', 'updated_at'),
              state_lock_version: 0,
              use_billing: true
            }
          }
        end

        context 'correct' do
          it 'properly updates and increment version' do
            post :update, params: post_params
            expect(order.state_lock_version).to eq 1
          end
        end

        context 'incorrect' do
          before do
            order.update_columns(state_lock_version: 1, state: 'address')
          end

          it 'order should receieve ensure_valid_order_version callback' do
            expect_any_instance_of(described_class).to receive(:ensure_valid_state_lock_version)
            post :update, params: post_params
          end

          it 'order should receieve with_lock message' do
            expect(order).to receive(:with_lock)
            post :update, params: post_params
          end

          it 'redirects back to current state' do
            post :update, params: post_params
            expect(response).to redirect_to spree.checkout_state_path('address')
            expect(flash[:error]).to eq 'The order has already been updated.'
          end
        end
      end
    end

    context 'save unsuccessful' do
      before do
        allow(order).to receive_messages user: user
        allow(order).to receive_messages update: false
      end

      it 'does not assign order' do
        post :update, params: { state: 'address' }
        expect(assigns[:order]).not_to be_nil
      end

      it 'does not change the order state' do
        post :update, params: { state: 'address' }
      end

      it 'renders the edit template' do
        post :update, params: { state: 'address' }
        expect(response).to render_template :edit
      end

      it 'renders order in payment state when payment fails' do
        order.update_column(:state, 'confirm')
        allow(controller).to receive(:insufficient_payment?).and_return(true)
        post :update, params: { state: 'confirm' }
        expect(order.state).to eq('payment')
      end
    end

    context 'when current_order is nil' do
      before { allow(controller).to receive_messages current_order: nil }

      it 'does not change the state if order is completed' do
        expect(order).not_to receive(:update_attribute)
        post :update, params: { state: 'confirm' }
      end

      it 'redirects to the cart_path' do
        post :update, params: { state: 'confirm' }
        expect(response).to redirect_to spree.cart_path
      end
    end

    context 'Spree::Core::GatewayError' do
      before do
        allow(order).to receive_messages user: user
        allow(order).to receive(:update).and_raise(Spree::Core::GatewayError.new('Invalid something or other.'))
        post :update, params: { state: 'address' }
      end

      it 'renders the edit template and display exception message' do
        expect(response).to render_template :edit
        expect(flash.now[:error]).to eq(Spree.t(:spree_gateway_error_flash_for_checkout))
        expect(assigns(:order).errors[:base]).to include('Invalid something or other.')
      end
    end

    context 'fails to transition from address' do
      let(:order) do
        FactoryBot.create(:order_with_line_items).tap do |order|
          order.next!
          expect(order.state).to eq('address')
        end
      end

      before do
        allow(controller).to receive_messages current_order: order
        allow(controller).to receive_messages check_authorization: true
      end

      context 'when the country is not a shippable country' do
        before do
          order.ship_address.tap do |address|
            # A different country which is not included in the list of shippable countries
            address.country = FactoryBot.create(:country, name: 'Australia')
            address.state_name = 'Victoria'
            address.save
          end
        end

        it 'due to no available shipping rates for any of the shipments' do
          expect(order.shipments.count).to eq(1)
          order.shipments.first.shipping_rates.delete_all

          put :update, params: { state: order.state, order: {} }
          expect(flash[:error]).to eq(Spree.t(:items_cannot_be_shipped))
          expect(response).to redirect_to(spree.checkout_state_path('address'))
        end
      end

      context 'when the order is invalid' do
        before do
          allow(order).to receive_messages(update_from_params: true, next: nil)
          order.errors.add(:base, 'Base error')
          order.errors.add(:adjustments, 'error')
        end

        it 'due to the order having errors' do
          put :update, params: { state: order.state, order: {} }
          expect(flash[:error]).to eql("Base error\nAdjustments error")
          expect(response).to redirect_to(spree.checkout_state_path('address'))
        end
      end
    end

    context 'fails to transition from payment to complete' do
      let(:order) do
        FactoryBot.create(:order_with_line_items).tap do |order|
          order.next! until order.state == 'payment'
          # So that the confirmation step is skipped and we get straight to the action.
          payment_method = FactoryBot.create(:simple_credit_card_payment_method)
          payment = FactoryBot.create(:payment, payment_method: payment_method)
          order.payments << payment
        end
      end

      before do
        allow(controller).to receive_messages current_order: order
        allow(controller).to receive_messages check_authorization: true
      end

      it 'when GatewayError is raised' do
        allow_any_instance_of(Spree::Payment).to receive(:process!).and_raise(Spree::Core::GatewayError.new(Spree.t(:payment_processing_failed)))
        put :update, params: { state: order.state, order: {} }
        expect(flash[:error]).to eq(Spree.t(:payment_processing_failed))
      end
    end
  end

  context 'When last inventory item has been purchased' do
    let(:product) { mock_model(Spree::Product, name: 'Amazing Object') }
    let(:variant) { mock_model(Spree::Variant) }
    let(:line_item) { mock_model Spree::LineItem, insufficient_stock?: true, amount: 0 }
    let(:order) { create(:order_with_line_items) }

    before do
      allow(order).to receive_messages(insufficient_stock_lines: [line_item], state: 'payment')

      configure_spree_preferences do |config|
        config.track_inventory_levels = true
      end
    end

    context 'and back orders are not allowed' do
      before do
        post :update, params: { state: 'payment' }
      end

      it 'redirects to cart' do
        expect(response).to redirect_to spree.cart_path
      end

      it 'sets flash message for no inventory' do
        expect(flash[:error]).to eq(
          Spree.t(:inventory_error_flash_for_insufficient_quantity, names: "'#{product.name}'")
        )
      end
    end
  end

  context "order doesn't have a delivery step" do
    before do
      allow(order).to receive_messages(checkout_steps: ['cart', 'address', 'payment'])
      allow(order).to receive_messages state: 'address'
      allow(controller).to receive_messages check_authorization: true
    end

    it "doesn't set shipping address on the order" do
      expect(order).not_to receive(:ship_address=)
      post :update, params: { state: order.state }
    end

    it "doesn't remove unshippable items before payment" do
      expect { post :update, params: { state: 'payment' } }.
        not_to change(order, :line_items)
    end
  end

  it 'does remove unshippable items before payment' do
    allow(order).to receive_messages payment_required?: true
    allow(controller).to receive_messages check_authorization: true

    expect { post :update, params: { state: 'payment' } }.
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
      put :update, params: { state: 'payment',
                         order: { payments_attributes: [{ payment_method_id: payment_method_id }] }
                       }
      order.reload
      expect(order.state).to eq 'confirm'
      put :update, params: { state: 'payment',
                         order: { payments_attributes: [{ payment_method_id: payment_method_id }] }
                       }
      order.reload
      expect(order.state).to eq 'confirm'
    end

    context 'with store credits payment' do
      let(:user) { create(:user) }
      let(:credit_amount) { order.total + 1.00 }
      let(:put_attrs) do
        {
          state: 'payment',
          apply_store_credit: 'Apply Store Credit',
          order: {
            payments_attributes: [{ payment_method_id: payment_method_id }]
          }
        }
      end

      before do
        create(:store_credit_payment_method)
        create(:store_credit, user: user, amount: credit_amount)
      end

      def expect_one_store_credit_payment(order, amount)
        expect(order.payments.count).to eq 1
        expect(order.payments.first.source).to be_a Spree::StoreCredit
        expect(order.payments.first.amount).to eq amount
      end

      it 'can fully pay with store credits while removing other payment attributes' do
        put :update, params: put_attrs

        order.reload
        expect(order.state).to eq 'confirm'
        expect_one_store_credit_payment(order, order.total)
      end

      it 'can fully pay with store credits while removing an existing card' do
        credit_card = create(:credit_card, user: user, payment_method: Spree::PaymentMethod.first)
        put_attrs[:order][:existing_card] = credit_card.id
        put :update, params: put_attrs

        order.reload
        expect(order.state).to eq 'confirm'
        expect_one_store_credit_payment(order, order.total)
      end

      context 'partial payment' do
        let(:credit_amount) { order.total - 1.00 }

        it 'returns to payment for partial store credit' do
          put :update, params: put_attrs

          order.reload
          expect(order.state).to eq 'payment'
          expect_one_store_credit_payment(order, credit_amount)
        end
      end
    end

    context 'remove store credits payment' do
      let(:user) { create(:user) }
      let(:credit_amount) { order.total - 1.00 }
      let(:put_attrs) do
        {
          state: 'payment',
          remove_store_credit: 'Remove Store Credit',
          order: {
            payments_attributes: [{ payment_method_id: payment_method_id }]
          }
        }
      end

      before do
        create(:store_credit_payment_method)
        create(:store_credit, user: user, amount: credit_amount)
        Spree::Checkout::AddStoreCredit.call(order: order)
      end

      def expect_invalid_store_credit_payment(order)
        expect(order.payments.store_credits.with_state(:invalid).count).to eq 1
        expect(order.payments.store_credits.with_state(:invalid).first.source).to be_a Spree::StoreCredit
      end

      it 'can fully pay with store credits while removing other payment attributes' do
        put :update, params: put_attrs

        order.reload
        expect(order.state).to eq 'payment'
        expect_invalid_store_credit_payment(order)
      end
    end
  end

  context 'Address Book' do
    let!(:user) { create(:user) }
    let!(:variant) { create(:product, sku: 'Demo-SKU').master }
    let!(:address) { create(:address, user: user) }
    let!(:order) { create(:order, bill_address_id: nil, ship_address_id: nil, user: user, state: 'address') }
    let(:address_params) { address.value_attributes.merge(firstname: 'Something Else') }

    before do
      Spree::Cart::AddItem.call(order: order, variant: variant, quantity: 1)
      allow(controller).to receive(:spree_current_user).and_return(user)
      allow(controller).to receive(:current_store).and_return(order.store)
      allow(order).to receive_messages user: user
      allow(order).to receive(:available_shipping_methods).and_return [stub_model(Spree::ShippingMethod)]
      allow(order).to receive(:available_payment_methods).and_return [stub_model(Spree::PaymentMethod)]
      allow(order).to receive(:ensure_available_shipping_rates).and_return true
    end

    describe 'on address step' do
      it 'set equal address ids' do
        put_address_to_order(bill_address_id: address.id, ship_address_id: address.id)
        expect(order.bill_address).to be_present
        expect(order.ship_address).to be_present
        expect(order.bill_address_id).to eq address.id
        expect(order.bill_address_id).to eq order.ship_address_id
      end

      it 'set bill_address_id and use_billing' do
        put_address_to_order(bill_address_id: address.id, use_billing: true)
        expect(order.bill_address).to be_present
        expect(order.ship_address).to be_present
        expect(order.bill_address_id).to eq address.id
        expect(order.bill_address_id).to eq order.ship_address_id
      end

      it 'set address attributes' do
        put_address_to_order(bill_address_attributes: address_params, use_billing: true, save_user_address: '1')
        expect(order.bill_address).not_to be_nil
        expect(order.ship_address).not_to be_nil
        expect(order.bill_address_id).to eq order.ship_address_id
      end
    end

    private

    def put_address_to_order(params)
      put :update, params: { state: 'address', order: params }
      order.reload
    end
  end
end
