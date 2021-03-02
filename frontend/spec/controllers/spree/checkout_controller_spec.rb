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

  describe '#edit' do
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

  describe '#update' do
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
        subject :update do
          patch :update, params: update_params
          order.reload
        end

        let(:user) { create(:user) }
        let(:order) do
          create(:order_with_totals,
                 bill_address: bill_address,
                 ship_address: ship_address,
                 state: 'address',
                 user: user)
        end
        let(:save_user_address) { true }
        let(:update_params) do
          {
            state: 'address',
            save_user_address: save_user_address,
            order: {
              bill_address_attributes: bill_address_params,
              ship_address_attributes: ship_address_params,
              use_billing: use_billing
            }
          }
        end

        shared_examples 'address not created' do
          it 'does not create new address' do
            expect { update }.to change { Spree::Address.count }.by(0)
          end
        end

        shared_examples 'new address created' do
          it 'creates new address' do
            expect { update }.to change { Spree::Address.count }.by(1)
          end
        end

        shared_examples 'created address assigned to current user' do
          it 'assigns created address to current user' do
            update

            expect(Spree::Address.last.user_id).to eq user.id
          end
        end

        shared_examples 'default address not changed' do
          it 'does not change default address' do
            update

            expect(default_bill_address.reload.city).to eq 'Herndon'
          end
        end

        shared_examples 'address user not changed' do
          it 'keeps address assigned to user' do
            update

            expect(default_bill_address.reload.user).to eq user
          end
        end

        shared_examples 'same user assigned' do
          it 'keeps addresses assigned to user' do
            update

            expect(default_bill_address.reload.user).to eq user
            expect(default_ship_address.reload.user).to eq user
          end
        end

        context 'with a billing and shipping address (with delivery step)' do
          let(:bill_address) { create(:address, user: user) }
          let(:ship_address) { create(:address, user: user) }

          context 'when all addresses attributes are nil' do
            let(:use_billing) { false }
            let(:bill_address_params) { nil }
            let(:ship_address_params) { nil }
            let(:expected_bill_address_id) { order.bill_address_id }
            let(:expected_ship_address_id) { order.ship_address_id }

            it 'takes default bill and ship addresses' do
              update

              expect(order.bill_address_id).to eq(expected_bill_address_id)
              expect(order.ship_address_id).to eq(expected_ship_address_id)
            end

            it_behaves_like 'address not created'
          end

          context 'when some attributes are invalid' do
            let(:use_billing) { false }
            let!(:default_bill_address) { order.bill_address }
            let!(:default_ship_address) { order.ship_address }
            let(:bill_address_params) { build(:address, firstname: nil, city: 'Chicago').attributes.merge(id: default_bill_address.id).except(:user_id, :created_at, :updated_at) }
            let(:ship_address_params) { build(:address, firstname: nil, city: 'Washington').attributes.merge(id: default_ship_address.id).except(:user_id, :created_at, :updated_at) }
            let(:bill_address_error) { { "bill_address.firstname": ["can't be blank"] } }
            let(:ship_address_error) { { "ship_address.firstname": ["can't be blank"] } }

            it 'returns address with errors' do
              update

              expect(order.errors.to_hash).to include(bill_address_error)
              expect(order.errors.to_hash).to include(ship_address_error)
            end

            it_behaves_like 'address not created'
          end

          context 'when addresses attributes are not changed' do
            let(:use_billing) { false }
            let(:bill_address_params) { order.bill_address.attributes.except(:user_id, :created_at, :updated_at) }
            let(:ship_address_params) { order.ship_address.attributes.except(:user_id, :created_at, :updated_at) }
            let(:expected_bill_address_id) { order.bill_address_id }
            let(:expected_ship_address_id) { order.ship_address_id }

            it 'takes same default addresses' do
              update

              expect(order.bill_address_id).to eq(expected_bill_address_id)
              expect(order.ship_address_id).to eq(expected_ship_address_id)
            end

            it_behaves_like 'address not created'
          end

          context 'when addresses attributes are changed' do
            let!(:default_bill_address) { order.bill_address }
            let!(:default_ship_address) { order.ship_address }

            context 'when default address is editable' do
              let(:use_billing) { false }
              let(:bill_address_params) { build(:address, city: 'Chicago').attributes.merge(id: default_bill_address.id).except(:user_id, :created_at, :updated_at) }
              let(:ship_address_params) { build(:address, city: 'Washington').attributes.merge(id: default_ship_address.id).except(:user_id, :created_at, :updated_at) }

              it 'updates current addresses' do
                expect(default_bill_address.city).to eq 'Herndon'
                expect(default_ship_address.city).to eq 'Herndon'

                update

                expect(default_bill_address.reload.city).to eq 'Chicago'
                expect(default_ship_address.reload.city).to eq 'Washington'
              end

              it_behaves_like 'address not created'
              it_behaves_like 'same user assigned'
            end

            context 'when default address is not editable' do
              let(:use_billing) { true }
              let!(:shipment) { create(:shipment, address: default_bill_address) }
              let(:bill_address_params) { build(:address, city: 'Chicago').attributes.merge(id: default_bill_address.id).except(:user_id, :created_at, :updated_at) }
              let(:ship_address_params) { build(:address, city: 'Washington').attributes.merge(id: default_ship_address.id).except(:user_id, :created_at, :updated_at) }
              let(:created_address_id) { Spree::Address.find_by(city: 'Chicago').id }

              it_behaves_like 'default address not changed'
              it_behaves_like 'new address created'

              it 'assigns created address to both bill and ship addresses' do
                update

                expect(order.bill_address_id).to eq created_address_id
                expect(order.ship_address_id).to eq created_address_id
              end

              it_behaves_like 'created address assigned to current user'

              context 'when save_user_addresss is falsy' do
                let(:save_user_address) { nil }

                it 'does not assign created address to current user' do
                  update

                  expect(order.bill_address.reload.user).to be_nil
                  expect(order.ship_address.reload.user).to be_nil
                end
              end
            end

            context 'when addresses are the same but have different ids' do
              let(:use_billing) { false }
              let(:bill_address_params) { default_bill_address.attributes.except(:user_id, :created_at, :updated_at) }
              let(:ship_address_params) { default_ship_address.attributes.except(:user_id, :created_at, :updated_at) }

              before { order.ship_address.update(state_id: order.bill_address.state_id) }

              it 'assigns bill address to ship address' do
                expect(order.bill_address.id).to eq default_bill_address.id

                update

                expect(order.bill_address.id).to eq default_ship_address.id
              end

              it 'destroys default bill address' do
                expect { update }.to change { Spree::Address.count }.by(-1)
              end
            end
          end

          context 'when user is a guest' do
            let(:user) { nil }
            let(:use_billing) { false }

            before do
              allow(controller).to receive_messages try_spree_current_user: nil
              allow(controller).to receive_messages spree_current_user: nil

              expect(controller).to receive(:authorize!).at_least(:once).and_return(true)
            end

            context 'when submitted addresses already exist' do
              let!(:bill_address) { create(:address, city: 'Chicago', user: nil) }
              let!(:ship_address) { create(:address, city: 'Washington', user: nil) }
              let(:order) { create(:order_with_totals, bill_address: nil, ship_address: nil, state: 'address', user: nil, email: 'example@email.com') }
              let(:bill_address_params) { bill_address.attributes.except(:id, :user_id, :created_at, :updated_at) }
              let(:ship_address_params) { ship_address.attributes.except(:id, :user_id, :created_at, :updated_at) }

              it 'keeps addresses unassigned' do
                update

                expect(bill_address.reload.user).to be_nil
                expect(ship_address.reload.user).to be_nil
              end

              it_behaves_like 'address not created'
            end

            context 'when submitted addresses does not exist' do
              let(:order) { create(:order_with_totals, bill_address: nil, ship_address: nil, state: 'address', user: nil, email: 'example@email.com') }
              let(:bill_address_params) { build(:address, city: 'Chicago', user: nil).attributes.except(:user_id, :created_at, :updated_at) }
              let(:ship_address_params) { build(:address, city: 'Washington', user: nil).attributes.except(:user_id, :created_at, :updated_at) }

              it 'keeps created addresses unassigned' do
                update

                expect(Spree::Address.find_by(city: 'Chicago').user).to be_nil
                expect(Spree::Address.find_by(city: 'Washington').user).to be_nil
              end

              it 'creates new addresses' do
                expect { update }.to change { Spree::Address.count }.by(2)
              end
            end

            context 'when attributes are invalid' do
              let(:order) { create(:order_with_totals, bill_address: nil, ship_address: nil, state: 'address', user: nil, email: 'example@email.com') }
              let(:bill_address_params) { build(:address, firstname: nil, city: 'Chicago', user: nil).attributes.except(:user_id, :created_at, :updated_at) }
              let(:ship_address_params) { build(:address, firstname: nil, city: 'Washington', user: nil).attributes.except(:user_id, :created_at, :updated_at) }
              let(:bill_address_error) { { "bill_address.firstname": ["can't be blank"] } }
              let(:ship_address_error) { { "ship_address.firstname": ["can't be blank"] } }

              it 'returns address with errors' do
                update

                expect(order.errors.to_hash).to include(bill_address_error)
                expect(order.errors.to_hash).to include(ship_address_error)
              end

              it_behaves_like 'address not created'
            end
          end
        end

        context 'with a billing address and without shipping address (without delivery step)' do
          let(:bill_address) { create(:address, user: user) }
          let(:ship_address) { nil }
          let(:bill_address_params) { nil }
          let(:ship_address_params) { nil }
          let(:use_billing) { nil }
          let(:expected_bill_address_id) { order.bill_address_id }

          before do
            allow(order).to receive_messages(checkout_steps: ['cart', 'address', 'payment'])
          end

          it "doesn't set shipping address" do
            expect(order).not_to receive(:ship_address=)

            update
          end

          context 'when all address attributes are nil' do
            let(:bill_address_params) { nil }
            let(:expected_bill_address_id) { order.bill_address_id }

            it 'takes default bill address' do
              update

              expect(order.bill_address_id).to eq(expected_bill_address_id)
            end

            it_behaves_like 'address not created'
          end

          context 'when some attributes are invalid' do
            let(:use_billing) { false }
            let!(:default_bill_address) { order.bill_address }
            let(:bill_address_params) { build(:address, firstname: nil, city: 'Chicago').attributes.merge(id: default_bill_address.id).except(:user_id, :created_at, :updated_at) }
            let(:bill_address_error) { { "bill_address.firstname": ["can't be blank"] } }

            it 'returns address with errors' do
              update

              expect(order.errors.to_hash).to include(bill_address_error)
            end

            it_behaves_like 'address not created'
          end

          context 'when bill address attributes are not changed' do
            let(:bill_address_params) { order.bill_address.attributes.except(:user_id, :created_at, :updated_at) }
            let(:expected_bill_address_id) { order.bill_address_id }

            it 'takes same default bill address' do
              update

              expect(order.bill_address_id).to eq(expected_bill_address_id)
            end

            it_behaves_like 'address not created'
          end

          context 'when addresses attributes are changed' do
            let!(:default_bill_address) { order.bill_address }

            context 'when default address is editable' do
              let(:bill_address_params) { build(:address, city: 'Chicago').attributes.merge(id: default_bill_address.id).except(:user_id, :created_at, :updated_at) }

              it 'updates current address' do
                expect(default_bill_address.city).to eq 'Herndon'

                update

                expect(default_bill_address.reload.city).to eq 'Chicago'
              end

              it_behaves_like 'address not created'
              it_behaves_like 'address user not changed'

              context 'when using API, with save_user_addresss set to true' do
                let(:save_user_address) { true }

                it_behaves_like 'address user not changed'
              end
            end

            context 'when default address is not editable' do
              let!(:shipment) { create(:shipment, address: default_bill_address) }
              let(:bill_address_params) { build(:address, city: 'Chicago').attributes.merge(id: default_bill_address.id).except(:user_id, :created_at, :updated_at) }
              let(:created_address_id) { Spree::Address.find_by(city: 'Chicago').id }

              it_behaves_like 'default address not changed'
              it_behaves_like 'new address created'

              it 'assigns created address to bill address' do
                update

                expect(order.bill_address_id).to eq created_address_id
              end

              it_behaves_like 'created address assigned to current user'

              context 'when save_user_addresss is falsy' do
                let(:save_user_address) { nil }

                it 'does not assign created address to current user' do
                  update

                  expect(order.bill_address.reload.user).to be_nil
                end
              end
            end
          end

          context 'when user is a guest' do
            let(:user) { nil }

            before do
              allow(controller).to receive_messages try_spree_current_user: nil
              allow(controller).to receive_messages spree_current_user: nil

              expect(controller).to receive(:authorize!).at_least(:once).and_return(true)
            end

            context 'when submitted bill address already exists' do
              let!(:bill_address) { create(:address, city: 'Chicago', user: nil) }
              let(:order) { create(:order_with_totals, bill_address: nil, ship_address: nil, state: 'address', user: nil, email: 'exaple@email.com') }
              let(:bill_address_params) { bill_address.attributes.except(:id, :user_id, :created_at, :updated_at) }

              it 'keeps address unassigned' do
                update

                expect(bill_address.reload.user).to be_nil
              end

              it_behaves_like 'address not created'
            end

            context 'when submitted bill address does not exits' do
              let(:order) { create(:order_with_totals, bill_address: nil, ship_address: nil, state: 'address', user: nil, email: 'example@email.com') }
              let(:bill_address_params) { build(:address, city: 'Chicago', user: nil).attributes.except(:user_id, :created_at, :updated_at) }

              it 'keeps created address unassigned' do
                update

                expect(Spree::Address.find_by(city: 'Chicago').user).to be_nil
              end

              it_behaves_like 'new address created'
            end

            context 'when attributes are invalid' do
              let(:order) { create(:order_with_totals, bill_address: nil, ship_address: nil, state: 'address', user: nil, email: 'example@email.com') }
              let(:bill_address_params) { build(:address, firstname: nil, city: 'Chicago', user: nil).attributes.except(:user_id, :created_at, :updated_at) }
              let(:bill_address_error) { { "bill_address.firstname": ["can't be blank"] } }

              it 'returns address with errors' do
                update

                expect(order.errors.to_hash).to include(bill_address_error)
              end

              it_behaves_like 'address not created'
            end
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
                             order: { payments_attributes: [{ payment_method_id: payment_method_id }] } }
      order.reload
      expect(order.state).to eq 'confirm'
      put :update, params: { state: 'payment',
                             order: { payments_attributes: [{ payment_method_id: payment_method_id }] } }
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
