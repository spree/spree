require 'spec_helper'

describe Spree::CheckoutController, type: :controller do
  let(:store) { @default_store }
  let(:address_params) do
    address = build(:address, country: country, state: state)
    address.attributes.except('created_at', 'updated_at')
  end
  let(:accept_marketing) { true }
  let(:country) { store.default_country || create(:country_us) }
  let!(:state) { create(:state, country: country, name: 'New York', abbr: 'NY') }
  let(:user) { nil }
  let(:order) { create(:order_with_totals, store: store, user: user, email: 'example@email.com') }

  render_views


  before do
    allow(controller).to receive_messages(
      current_store: store,
      try_spree_current_user: user,
      spree_current_user: user,
      spree_signup_path: '/signup',
      spree_login_path: '/login'
    )
  end

  describe '#edit' do
    it 'redirects to the cart path if token is invalid' do
      get :edit, params: { state: 'delivery', token: 'INVALID' }
      expect(response).to redirect_to(spree.cart_path)
    end

    it 'redirects to cart if order is completed' do
      order.update_columns(completed_at: Time.current, state: 'complete')
      get :edit, params: { state: 'address', token: order.token }
      expect(response).to redirect_to(spree.cart_path)
    end

    it 'redirects to cart if order has removed line items' do
      product = order.line_items.first.product

      order.update_column(:state, 'delivery')

      get :edit, params: { state: 'delivery', token: order.token }
      expect(response).not_to redirect_to(spree.cart_path)

      product.update!(status: 'draft')
      get :edit, params: { state: 'delivery', token: order.token }

      expect(response).to redirect_to(spree.cart_path)
      expect(flash[:error]).to eq(Spree.t('cart_line_item.discontinued', li_name: product.name))
    end

    it 'redirects to current step trying to access a future step' do
      order.update_column(:state, 'address')
      get :edit, params: { state: 'delivery', token: order.token }
      expect(response).to redirect_to spree.checkout_state_path(order.token, 'address')
    end

    it 'sets the order state to address if it is cart' do
      order.update_column(:state, 'cart')
      expect(get(:edit, params: { token: order.token })).to redirect_to(spree.checkout_state_path(order.token, 'address'))
      expect(order.reload.state).to eql('address')
    end

    it 'tracks events' do
      expect(controller).to receive(:track_event).with('checkout_started', { order: order })
      expect(controller).to receive(:track_event).with('checkout_step_viewed', { order: order, step: 'address' })
      get :edit, params: { token: order.token, state: 'address' }

      expect(assigns(:order).accept_marketing).to be(true)
      expect(assigns(:order).signup_for_an_account).to be(true)
    end

    describe 'special instructions field visibility' do
      before do
        order.update_column(:state, 'address')
      end

      context 'when special instructions preference is enabled' do
        before { store.update!(preferred_special_instructions_enabled: true) }

        after  { store.update!(preferred_special_instructions_enabled: false) }

        it 'renders the special instructions field' do
          get :edit, params: { token: order.token, state: 'address' }
          expect(response.body).to include('special_instructions')
          expect(response.body).to include(I18n.t('activerecord.attributes.spree/order.special_instructions'))
        end
      end

      context 'when special instructions preference is disabled' do
        before { store.update!(preferred_special_instructions_enabled: false) }

        it 'does not render the special instructions field' do
          get :edit, params: { token: order.token, state: 'address' }
          expect(response.body).not_to include('special_instructions')
        end
      end
    end

    context 'when user is not signed in' do
      let(:user) { nil }

      before do
        allow(store).to receive(:prefers_guest_checkout?).and_return(allow_guest_checkout)
      end

      context 'when guest checkout is allowed' do
        let(:allow_guest_checkout) { true }

        it 'allows access to the checkout' do
          get :edit, params: { token: order.token }
          expect(response).to redirect_to(spree.checkout_state_path(order.token, 'address'))
        end
      end

      context 'when guest checkout is not allowed' do
        let(:allow_guest_checkout) { false }

        it 'redirects to the sign up page' do
          get :edit, params: { token: order.token }
          expect(response).to redirect_to('/signup')
        end
      end
    end

    context 'when entering the checkout' do
      context 'when user is signed in' do
        let(:user) { create(:user) }

        it 'associates the order with a user' do
          order.update_column :user_id, nil
          expect { get :edit, params: { token: order.token } }.to change { order.reload.user }.from(nil).to(user)
        end
      end

      context 'when order has no user assigned to it' do
        let(:user) { create(:user) }

        before do
          order.update_column :user_id, nil
        end

        it 'allows any user to access the order' do
          get :edit, params: { token: order.token }
          expect(response).to redirect_to spree.checkout_state_path(order.token, 'address')
        end
      end

      context 'when order has user assigned to it' do
        let(:order_user) { create(:user) }

        before do
          order.update_column :user_id, order_user.id
        end

        context 'when user is not logged in' do
          let(:user) { nil }

          it 'redirects to login page' do
            get :edit, params: { token: order.token }
            expect(response).to redirect_to('/login')
          end

          context 'when guest checkout is allowed' do
            let(:allow_guest_checkout) { true }

            it 'creates a new order and allows access to the checkout' do
              expect {
                get :edit, params: { token: order.token, guest: true }
              }.to change(Spree::Order, :count).by(1)

              new_order = Spree::Order.last

              expect(response).to redirect_to(spree.checkout_path(new_order.token))
            end
          end
        end

        context 'when user is logged in' do
          context 'when user is the order user' do
            let(:user) { order_user }

            it 'allows user to access the order' do
              get :edit, params: { token: order.token }
              expect(response).to redirect_to spree.checkout_state_path(order.token, 'address')
            end
          end

          context 'when user is not the order user' do
            let(:user) { create(:user) }

            it 'redirects to cart page' do
              get :edit, params: { token: order.token }
              expect(flash[:error]).to eq('You cannot access this checkout')
              expect(response).to redirect_to(spree.cart_path)
            end
          end
        end
      end
    end

    describe 'before_action :restart_checkout' do
      shared_examples_for 'restarting checkout' do
        context 'on address step' do
          before do
            order.update!(state: 'address')
          end

          it 'proceeds with the checkout' do
            get :edit, params: { token: order.token }
            expect(response).to be_ok
          end
        end

        context 'on delivery step' do
          before do
            order.update!(ship_address: address, state: 'delivery')
          end

          it 'redirects back to the address step' do
            get :edit, params: { token: order.token }

            expect(response).to redirect_to(spree.checkout_state_path(order.token, 'address'))

            expect(order.reload).to be_address
            expect(order.ship_address).to eq(nil)
          end
        end

        context 'on payment step' do
          before do
            order.update!(ship_address: address, state: 'payment')
          end

          it 'redirects back to the address step' do
            get :edit, params: { token: order.token }

            expect(response).to redirect_to(spree.checkout_state_path(order.token, 'address'))

            expect(order.reload).to be_address
            expect(order.ship_address).to eq(nil)
          end
        end
      end

      context 'on quick checkout' do
        let(:address) { create(:address, quick_checkout: true, country: country, state: state) }

        include_examples 'restarting checkout'
      end

      context 'with a missing shipping address' do
        let(:address) { nil }

        include_examples 'restarting checkout'

        context 'when the order does not require a shipping address' do
          let(:digital_shipping_method) { create(:digital_shipping_method) }
          let(:digital_product) { create(:product, shipping_category: digital_shipping_method.shipping_categories.first) }
          let(:order) { create(:order_with_line_items, variants: [digital_product.default_variant], state: 'payment', ship_address: nil, store: store, user: user, email: 'example@email.com') }

          it 'does not redirect to the address step' do
            get :edit, params: { token: order.token }
            expect(response).to be_ok
            expect(response).not_to redirect_to(spree.checkout_state_path(order.token, 'address'))
          end
        end
      end
    end

    context 'removes expired gift card' do
      let!(:gift_card) { create :gift_card, code: '123', amount: 10, state: 'active' }

      before do
        order.update(state: :address)
        order.update_column(:total, 30)

        patch :apply_coupon_code, params: { token: order.token, coupon_code: gift_card.code.upcase }
        gift_card.update_columns(expires_at: 1.day.ago)
      end

      it 'removes gift card from order' do
        expect(order.reload.gift_card).to eq(gift_card)

        get :edit, params: { token: order.token }

        expect(order.reload.gift_card).to eq(nil)
      end
    end
  end

  describe '#update' do
    context 'save successful' do
      before do
        allow_any_instance_of(Spree::Order).to receive(:ensure_available_shipping_rates).and_return(true)
      end

      def spree_post_address
        post :update, params: {
          token: order.token,
          state: 'address',
          order: {
            ship_address_attributes: address_params
          }
        }
      end

      context 'with the order in the cart state' do
        before do
          order.update_column(:state, 'cart')
          allow(order).to receive_messages user: user
        end

        it 'assigns order' do
          post :update, params: { state: 'address', token: order.token }
          expect(assigns[:order]).not_to be_nil
        end

        it 'advances the state' do
          spree_post_address
          expect(order.reload.state).to eq('delivery')
        end

        it 'tracks events' do
          expect(controller).to receive(:track_event).with('checkout_step_completed', { order: order, step: 'address' })
          spree_post_address
        end

        it 'redirects the next state' do
          spree_post_address
          expect(response).to redirect_to spree.checkout_state_path(order.token, 'delivery')
        end
      end

      context 'with the order in the address state' do
        subject :update do
          patch :update, params: update_params
          order.reload
        end

        let(:user) { create(:user) }
        let(:ship_address) { nil }

        let!(:order) do
          create(:order_with_totals,
                 ship_address: ship_address,
                 state: 'address',
                 user: user,
                 store: store)
        end
        let(:save_user_address) { true }
        let(:update_params) do
          {
            token: order.token,
            state: 'address',
            save_user_address: save_user_address,
            accept_marketing: accept_marketing,
            order: {
              ship_address_attributes: ship_address_params,
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

            expect(default_ship_address.reload.city).to eq 'Herndon'
          end
        end

        shared_examples 'address user not changed' do
          it 'keeps address assigned to user' do
            update

            expect(default_ship_address.reload.user).to eq user
          end
        end

        shared_examples 'same user assigned' do
          it 'keeps addresses assigned to user' do
            update

            expect(default_ship_address.reload.user).to eq user
          end
        end

        context 'with shipping address (with delivery step)' do
          let(:ship_address) { create(:address, user: user, country: country, state: state) }

          context 'when all addresses attributes are nil' do
            let!(:ship_address_params) { nil }
            let(:expected_ship_address_id) { order.ship_address_id }

            it 'takes default ship addresses' do
              update

              expect(order.ship_address_id).to eq(expected_ship_address_id)
            end

            it_behaves_like 'address not created'
          end

          context 'when some attributes are invalid' do
            let!(:default_ship_address) { order.ship_address }
            let(:ship_address_params) do
              build(:address, firstname: nil, city: 'Washington').attributes.merge(id: default_ship_address.id).except(:user_id, :created_at,
                                                                                                                       :updated_at)
            end
            let(:ship_address_error) { { 'ship_address.firstname': ["can't be blank"] } }

            it_behaves_like 'address not created'
          end

          context 'when addresses attributes are not changed' do
            let(:ship_address_params) { order.ship_address.attributes.except(:user_id, :created_at, :updated_at) }
            let(:expected_ship_address_id) { order.ship_address_id }

            it 'takes same default addresses' do
              update

              expect(order.ship_address_id).to eq(expected_ship_address_id)
            end

            it_behaves_like 'address not created'
          end

          context 'when addresses attributes are changed' do
            let!(:default_ship_address) { order.ship_address }

            context 'when default address is editable' do
              let(:ship_address_params) do
                {
                  firstname: 'John',
                  lastname: 'Doe',
                  address1: '123 DC',
                  city: 'Washington',
                  zipcode: '12345',
                  phone: '123-456-7890',
                  state_id: default_ship_address.state_id,
                  country_id: default_ship_address.country_id,
                  id: default_ship_address.id
                }
              end

              it 'updates current addresses' do
                expect(default_ship_address.city).to eq 'Herndon'

                update

                expect(default_ship_address.reload.city).to eq 'Washington'
              end

              it_behaves_like 'address not created'
              it_behaves_like 'same user assigned'
            end

            context 'when default address is not editable' do
              let!(:completed_order) { create(:completed_order_with_totals, ship_address: default_ship_address) }
              let(:ship_address_params) do
                build(:address, city: 'Washington', state: state).attributes.merge(id: default_ship_address.id).except(:user_id, :created_at,
                                                                                                                       :updated_at)
              end
              let(:created_address_id) { Spree::Address.find_by(city: 'Washington').id }

              it_behaves_like 'default address not changed'
              it_behaves_like 'new address created'

              it 'assigns created address to both bill and ship addresses' do
                update

                expect(order.ship_address_id).to eq created_address_id
              end

              it_behaves_like 'created address assigned to current user'
            end
          end

          context 'when user is a guest' do
            let(:user) { nil }

            before do
              allow(controller).to receive_messages try_spree_current_user: nil
              allow(controller).to receive_messages spree_current_user: nil
            end

            context 'when submitted addresses already exist' do
              let!(:ship_address) { create(:address, city: 'Washington', user: nil, country: country, state: state) }
              let(:order) do
                create(:order_with_totals, store: store, bill_address: nil, ship_address: nil, state: 'address', user: nil,
                                           email: 'example@email.com')
              end
              let(:ship_address_params) { ship_address.attributes.except(:id, :user_id, :created_at, :updated_at) }

              it 'keeps addresses unassigned' do
                update

                expect(ship_address.reload.user).to be_nil
              end

              it_behaves_like 'address not created'
            end

            context 'when submitted addresses does not exist' do
              let(:order) do
                create(:order_with_totals, store: store, bill_address: nil, ship_address: nil, state: 'address', user: nil,
                                           email: 'example@email.com')
              end
              let(:ship_address_params) do
                build(:address, city: 'Washington', user: nil, state: state).attributes.except(:user_id, :created_at, :updated_at)
              end

              it 'keeps created addresses unassigned' do
                update

                expect(Spree::Address.find_by(city: 'Washington').user).to be_nil
              end

              it 'creates new addresses' do
                expect { update }.to change { Spree::Address.count }.by(1)
              end
            end

            context 'when attributes are invalid' do
              let(:order) do
                create(:order_with_totals, store: store, bill_address: nil, ship_address: nil, state: 'address', user: nil,
                                           email: 'example@email.com')
              end
              let(:ship_address_params) do
                build(:address, firstname: nil, city: 'Washington', user: nil).attributes.except(:user_id, :created_at, :updated_at)
              end
              let(:ship_address_error) { { 'ship_address.firstname': ["can't be blank"] } }

              it_behaves_like 'address not created'
            end
          end
        end

        describe 'address company field' do
          let(:company_name) { 'Test Company Inc.' }
          let(:ship_address_params) { build(:address, company: company_name, country: country, state: state).attributes.except(:user_id, :created_at, :updated_at) }

          before { store.update!(preferred_company_field_enabled: true) }

          after  { store.update!(preferred_company_field_enabled: false) }

          it 'saves company field when provided' do
            update
            expect(response).to have_http_status(:redirect)
            expect(order.ship_address.company).to eq('Test Company Inc.')
            expect(order.ship_address.user).to eq(user)
          end

          context 'when company field is empty' do
            let(:company_name) { '' }

            it 'saves address without company field' do
              update

              expect(response).to have_http_status(:redirect)
              expect(order.ship_address.company).to be_blank
              expect(order.ship_address.user).to eq(user)
            end
          end
        end

        describe 'special instructions' do
          let(:ship_address) { create(:address, user: user, country: country, state: state) }
          let(:special_instructions) { "Please leave at the front door.\nKnock on the door." }
          let(:ship_address_params) { order.ship_address.attributes.except(:user_id, :created_at, :updated_at) }
          let(:update_params) do
            {
              token: order.token,
              state: 'address',
              order: {
                ship_address_attributes: ship_address_params,
                special_instructions: special_instructions
              }
            }
          end

          before { store.update!(preferred_special_instructions_enabled: true) }

          after  { store.update!(preferred_special_instructions_enabled: false) }

          it 'saves special instructions when provided' do
            update
            expect(response).to have_http_status(:redirect)
            expect(order.special_instructions).to eq("Please leave at the front door.\nKnock on the door.")
          end

          context 'when special instructions is empty' do
            let(:special_instructions) { '' }

            it 'saves order without special instructions' do
              update

              expect(response).to have_http_status(:redirect)
              expect(order.special_instructions).to be_blank
            end
          end
        end
      end

      context 'with the order in the delivery state' do
        subject :update do
          patch :update, params: update_params
          order.reload
        end

        let(:ship_address) { create(:address, user: user, country: country, state: state) }
        let(:update_params) do
          {
            token: order.token,
            state: 'delivery',
            order: {
              selected_shipping_rate_id: order.shipments.first.shipping_rates.first.id
            }
          }
        end
        let(:order) { create(:order_with_line_items, state: 'delivery', ship_address: ship_address, user: user, store: store, email: 'test@example.com') }

        before do
          order.create_proposed_shipments
          order.send(:ensure_available_shipping_rates)
          order.set_shipments_cost
          order.reload
        end



        it 'sets shipping rate and moves to payment state' do
          expect(controller).to receive(:track_event).with('checkout_step_completed', { order: order, step: 'delivery' })
          expect { update }.to change { order.state }.from('delivery').to('payment')
          expect(order.shipments.first.selected_shipping_rate).to eq(order.shipments.first.shipping_rates.first)
        end
      end

      context 'with the order in the payment state' do
        subject :update do
          patch :update, params: update_params
          order.reload
        end

        let(:order) { create(:order_with_line_items, state: 'payment', user: user,store: store, email: 'test@example.com') }
        let(:payment_method) { create(:credit_card_payment_method, stores: [store]) }

        let(:payment_source_attributes) do
          {
            gateway_payment_profile_id: 'BGS-123',
            gateway_customer_profile_id: 'BGS-123',
            month: 1.month.from_now.month,
            year: 1.month.from_now.year,
            name: 'Spree Commerce',
            last_digits: '1111'
          }
        end

        let(:update_params) do
          {
            token: order.token,
            state: 'payment',
            order: {
              bill_address_attributes: {
                firstname: 'John',
                lastname: 'Doe',
                address1: '7735 Old Georgetown Road',
                city: 'Bethesda',
                zipcode: '20814',
                phone: '3014445002',
                state_id: state.id,
                country_id: country.id,
              },
              payments_attributes: [{
                payment_method_id: payment_method.id,
              }]
            },
            payment_source: {
              payment_method.id.to_s => payment_source_attributes
            }
          }
        end


        it 'saves payment method' do
          expect { update }.to change { order.payments.count }.by(1)
          expect(order.payment_method).to eq(payment_method)
          expect(order.payment_source.gateway_payment_profile_id).to eq('BGS-123')
        end

        it 'saves bill address' do
          expect { update }.to change { order.bill_address.address1 }.to('7735 Old Georgetown Road')
        end

        it 'moves to confirm state' do
          expect { update }.to change(order, :state).from('payment').to('confirm')
        end

        it 'tracks event' do
          expect(controller).to receive(:track_event).with('payment_info_entered', { order: order })
          expect(controller).to receive(:track_event).with('checkout_step_completed', { order: order, step: 'payment' })
          update
        end

        context 'bill address same as shipping' do
          let(:update_params) do
            {
              token: order.token,
              state: 'payment',
              order: {
                use_shipping: 'true',
                payments_attributes: [{
                  payment_method_id: payment_method.id,
                }]
              },
              payment_source: {
                payment_method.id.to_s => payment_source_attributes
              }
            }
          end

          it 'moves to confirm state' do
            expect { update }.to change { order.state }.from('payment').to('confirm')
          end

          it 'saves bill address' do
            expect { update }.to change { order.bill_address }.to(order.ship_address)
          end
        end

        context 'without confirmation required' do
          before do
            allow_any_instance_of(Spree::Order).to receive(:confirmation_required?).and_return(false)
          end

          it 'moves to complete state' do
            expect(controller).to receive(:track_event).with('payment_info_entered', { order: order })
            expect(controller).to receive(:track_event).with('checkout_step_completed', { order: order, step: 'payment' })
            expect(controller).to receive(:track_event).with('order_completed', { order: order })
            expect { update }.to change { order.state }.from('payment').to('complete')
            expect(response).to redirect_to spree.checkout_complete_path(order.token)
          end
        end
      end

      context 'state_lock_version' do
        let(:post_params) do
          {
            token: order.token,
            state: 'address',
            order: {
              ship_address_attributes: {
                firstname: 'John',
                lastname: 'Doe',
                address1: '7735 Old Georgetown Road',
                city: 'Bethesda',
                zipcode: '20814',
                phone: '3014445002',
                state_id: state.id,
                country_id: country.id,
              },
              state_lock_version: 0
            }
          }
        end

        context 'correct' do
          it 'properly updates and increment version' do
            post :update, params: post_params
            expect(order.reload.state_lock_version).to eq 1
          end

          it 'order should receive ensure_valid_order_version callback' do
            expect_any_instance_of(described_class).to receive(:ensure_valid_state_lock_version)
            post :update, params: post_params
          end

          it 'order should have assigned changed attributes properly' do
            expect(order.last_ip_address).to be nil
            post :update, params: post_params
            expect(order.reload.last_ip_address).to eq '0.0.0.0'
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

          it 'redirects back to current state' do
            post :update, params: post_params
            expect(response).to redirect_to spree.checkout_state_path(order.token, 'address')
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
        post :update, params: { state: 'address', token: order.token }
        expect(assigns[:order]).not_to be_nil
      end

      it 'does not change the order state' do
        post :update, params: { state: 'address', token: order.token }
      end

      it 'renders the edit template' do
        post :update, params: { state: 'address', token: order.token }
        expect(response).to render_template :edit
      end
    end

    context 'Spree::Core::GatewayError' do
      before do
        allow_any_instance_of(Spree::Order).to receive(:update).and_raise(Spree::Core::GatewayError.new('Invalid something or other.'))
        post :update, params: { state: 'address', token: order.token }
      end

      it 'renders the edit template and display exception message' do
        expect(response).to render_template :edit
        expect(flash.now[:error]).to eq(Spree.t(:spree_gateway_error_flash_for_checkout))
        expect(assigns(:order).errors[:base]).to include('Invalid something or other.')
      end
    end

    context 'fails to transition from address' do
      let(:order) do
        create(:order_with_line_items).tap do |order|
          order.next!
          expect(order.state).to eq('address')
        end
      end

      context 'when the country is not a shippable country' do
        before do
          order.update_column(:user_id, nil)
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

          put :update, params: { state: order.state, order: {}, token: order.token }
          expect(flash[:error]).to eq(Spree.t(:products_cannot_be_shipped, product_names: order.products.pluck(:name).to_sentence))
          expect(response).to redirect_to(spree.checkout_state_path(order.token, 'address'))
        end
      end
    end

    context 'with missing shipping rates' do
      let(:address) { create(:address, country: country, state: state) }
      let!(:order) { create(:order_with_totals, store: store, ship_address: address, user: user) }

      before do
        allow_any_instance_of(Spree::Order).to receive_messages empty_rate_products: [order.line_items.first]
      end

      it 'renders update without redirect if missing items detected' do
        put :update, params: { state: 'address', order: {}, token: order.token },  format: :turbo_stream
        expect(response).not_to have_http_status(:redirect)
        expect(response).to render_template :update
      end
    end

    context 'When last inventory item has been purchased' do
      let(:product) { create(:product, name: 'Amazing Object') }
      let(:variant) { create(:variant, product: product) }
      let(:stock_item) { variant.stock_items.first }
      let(:line_item) { create(:line_item, variant: variant, quantity: 1) }
      let(:order) { create(:order_with_line_items, store: store, state: :payment, user_id: nil) }

      before do
        order.line_items << line_item
        stock_item.update(backorderable: false)
      end

      context 'and back orders are not allowed' do
        before do
          post :update, params: { state: 'payment', token: order.token }
        end

        it 'redirects to cart' do
          expect(response).to redirect_to spree.cart_path
        end

        it 'sets flash message for no inventory' do
          expect(flash[:error]).to eq(
            Spree.t('cart_line_item.out_of_stock', li_name: line_item.name)
          )
        end
      end
    end

    it 'does remove unshippable items before payment' do
      expect { post :update, params: { state: 'payment', token: order.token } }.to change { order.reload.line_items.size }
    end

    context 'Address Book' do
      let!(:user) { create(:user_with_addresses) }
      let!(:variant) { create(:product, sku: 'Demo-SKU').master }
      let!(:address) { user.ship_address }
      let!(:other_address) { create(:address, user: user, country: country, state: state) }
      let!(:order) { create(:order, store: store, bill_address_id: nil, ship_address_id: nil, user: user, state: 'address') }
      let(:address_params) { build(:address, country: country, state: state).attributes }

      before do
        Spree::Cart::AddItem.call(order: order, variant: variant, quantity: 1)
        allow(order).to receive(:available_shipping_methods).and_return [stub_model(Spree::ShippingMethod)]
        allow(order).to receive(:available_payment_methods).and_return [stub_model(Spree::PaymentMethod)]
        allow(order).to receive(:ensure_available_shipping_rates).and_return true
        allow(controller).to receive(:try_spree_current_user).and_return(user)
      end

      describe 'on address step' do
        it 'automatically selects existing address if user has one' do
          get :edit, params: { state: 'address', token: order.token }

          expect(controller.current_order.ship_address).to eq(address)
        end

        context 'when shipping address is not required' do
          before do
            allow_any_instance_of(Spree::Order).to receive(:requires_ship_address?).and_return(false)
          end

          it 'does not select existing address' do
            get :edit, params: { state: 'address', token: order.token }

            expect(controller.current_order.ship_address).to be_nil
          end
        end

        it 'can select existing address' do
          put_address_to_order(ship_address_id: other_address.id)
          expect(order.reload.ship_address).to eq(other_address)
        end

        it 'can create new address' do
          expect { put_address_to_order(ship_address_attributes: address_params) }.to change(user.addresses, :count).by(1)
          expect(order.ship_address).not_to be_nil
          expect(order.ship_address.user).to eq(user)
        end
      end

      private

      def put_address_to_order(params)
        put :update, params: { state: 'address', order: params, token: order.token }
        order.reload
      end
    end

    context 'same as shipping' do
      let(:user) { create(:user) }
      let(:ship_address) { create(:address, user: user, country: country, state: state) }
      let(:order) { create(:order_with_line_items, state: 'payment', store: store, bill_address: nil, ship_address: ship_address, user: user) }

      context 'same as shipping' do
        subject { patch :update, params: { token: order.token, state: 'payment', order: { use_shipping: 'true' } } }

        before do
          subject
          order.reload
          user.reload
        end

        it 'uses shipping address' do
          expect(order.bill_address).to eq(ship_address)
        end

        it 'sets the address as user billing default' do
          expect(user.bill_address).to eq(ship_address)
        end
      end

      context 'different from shipping' do
        let(:bill_address_attributes) do
          {
            firstname: 'John',
            lastname: 'Doe',
            address1: '7735 Old Georgetown Road',
            city: 'Bethesda',
            country_id: country.id,
            state_id: state.id,
            zipcode: '20814',
            phone: '3014445555'
          }
        end

        it 'creates new address and assigns it' do
          order
          expect { put :update, params: { token: order.token, state: 'payment', order: { bill_address_attributes: bill_address_attributes } } }.to change {
                                                                                                                                            order.reload.bill_address
                                                                                                                                          }.from(nil).to(an_instance_of(Spree::Address)).and change {
                                                                                                                                                                                                Spree::Address.count
                                                                                                                                                                                              }.by(1)
          expect(order.reload.billing_address).to be_present
          expect(order.billing_address.address1).to eq bill_address_attributes[:address1]
          expect(order.billing_address.user).to eq user

          expect(user.reload.bill_address).to eq(order.billing_address)
        end

        describe 'billing address company field' do
          let(:bill_address_with_company) { bill_address_attributes.merge(company: company_name) }

          before { store.update!(preferred_company_field_enabled: true) }

          after  { store.update!(preferred_company_field_enabled: false) }

          context 'when company field is provided' do
            let(:company_name) { 'Billing Company Corp.' }

            it 'saves company field in billing address' do
              put :update, params: { token: order.token, state: 'payment', order: { bill_address_attributes: bill_address_with_company } }

              expect(response).to have_http_status(:redirect)
              expect(order.reload.bill_address.company).to eq('Billing Company Corp.')
              expect(order.bill_address.user).to eq(user)
            end
          end

          context 'when company field is empty' do
            let(:company_name) { '' }

            it 'saves billing address without company field' do
              put :update, params: { token: order.token, state: 'payment', order: { bill_address_attributes: bill_address_with_company } }

              expect(response).to have_http_status(:redirect)
              expect(order.reload.bill_address.company).to be_blank
            end
          end
        end
      end
    end
  end

  describe '#complete' do
    context 'when order is in payment state' do
      let(:order) { create(:order_with_line_items, state: 'payment', store: store) }

      it 'redirects back to cart' do
        get :complete, params: { token: order.token }
        expect(response).to redirect_to spree.cart_path
      end
    end

    context 'when order is in complete state' do
      let(:order) { create(:completed_order_with_totals, store: store, user: order_user, signup_for_an_account: signup_for_an_account) }
      let(:signup_for_an_account) { false }

      context 'when checkout is associated with a user' do
        let(:order_user) { create(:user) }

        before { get :complete, params: { token: order.token } }

        it 'clears out the session' do
          expect(session[:checkout_completed]).to be_nil
        end

        context 'when user is signed in' do
          let(:user) { order_user }

          it 'renders the page' do
            expect(response).to render_template(:complete)
          end
        end

        context 'when other user is signed in' do
          let(:user) { create(:user) }

          it 'redirects to the cart' do
            expect(response).to redirect_to spree.cart_path
          end
        end

        context 'for a guest user' do
          let(:user) { nil }

          it 'redirects to the login page' do
            expect(response).to redirect_to('/login')
          end
        end
      end

      context 'when checkout is not associated with a user' do
        let(:order_user) { nil }

        before { get :complete, params: { token: order.token } }

        it 'clears out the session' do
          expect(session[:checkout_completed]).to be_nil
        end

        it 'renders the page' do
          expect(response).to render_template(:complete)
        end
      end

      context 'when a guest user signed up for an account' do
        let(:order_user) { create(:user) }
        let(:signup_for_an_account) { true }

        before do
          request.cookie_jar.signed[:token] = cookies_order_token
          get :complete, params: { token: order.token }
        end

        context 'when cookies order token is valid' do
          let(:cookies_order_token) { order.token }

          it 'renders the page' do
            expect(response).to render_template(:complete)
          end
        end

        context 'when cookies order token is invalid' do
          let(:cookies_order_token) { build(:order).token }

          it 'redirects to the login page' do
            expect(response).to redirect_to('/login')
          end
        end

        context 'when there is no cookies order token' do
          let(:cookies_order_token) { nil }

          it 'redirects to the login page' do
            expect(response).to redirect_to('/login')
          end
        end
      end
    end
  end

  describe '#apply_coupon_code' do
    subject { patch :apply_coupon_code, params: { token: order.token, coupon_code: coupon_code } }

    let(:user) { create(:user) }
    let!(:order) { create(:order_with_line_items, state: 'payment', store: store, bill_address: nil, user: user) }
    let!(:line_item) { create(:line_item, order: order) }
    let!(:shipment) { create(:shipment, order: order) }
    let!(:promotion) { create(:promotion, name: 'Free shipping', code: 'freeship', stores: [store]) }
    let!(:promotion_action) { Spree::PromotionAction.create(promotion_id: promotion.id, type: 'Spree::Promotion::Actions::FreeShipping') }


    context 'when coupon code is valid' do
      let(:coupon_code) { 'FREESHIP' }

      it 'applies the coupon code' do
        expect(controller).to receive(:track_event).with('coupon_entered', hash_including(order: order, coupon_code: coupon_code))
        expect(controller).to receive(:track_event).with('coupon_applied', hash_including(order: order, coupon_code: coupon_code))

        subject
        expect(response).to redirect_to spree.checkout_path(order.token)
        expect(order.reload.promotions).to include(promotion)
      end
    end

    context 'when coupon code is invalid' do
      let(:coupon_code) { 'fake_coupon_code' }

      it 'does not apply the coupon code' do
        expect(controller).to receive(:track_event).with('coupon_entered', hash_including(order: order, coupon_code: coupon_code))
        expect(controller).to receive(:track_event).with('coupon_denied', hash_including(order: order, coupon_code: coupon_code))

        subject
        expect(response).to redirect_to spree.checkout_path(order.token)
        expect(order.reload.promotions).to be_empty
      end
    end

    describe 'apply gift card' do
      subject { patch :apply_coupon_code, params: { token: order.token, coupon_code: gift_card.code.upcase } }

      let(:user) { create(:user) }
      let(:gift_card) { create :gift_card, store: store, user: user }
      let(:coupon_code) { gift_card.code.upcase }


      context 'when gift card is valid' do
        it 'applies the gift card' do
          expect(controller).to receive(:track_event).with('coupon_entered', hash_including(order: order, coupon_code: gift_card.code.upcase))
          expect(controller).to receive(:track_event).with('coupon_applied', hash_including(order: order, coupon_code: gift_card.code.upcase))

          subject
          expect(order.reload.gift_card).to eq(gift_card)
          expect(order.gift_card_total).to eq(gift_card.amount)
          expect(order.total_applied_store_credit).to eq(gift_card.amount)
        end
      end

      context 'applying a gift card already redeemed by order' do
        let!(:old_order) { create(:order_with_totals, store: store, user: user) }
        let(:gift_card) { create :gift_card, store: store, amount: 50 }
        let(:coupon_code) { gift_card.code.upcase }

        before do
          old_order.update_column(:total, 30)
          order.update_column(:total, 30)
        end

        it 'applies the gift card to both orders' do
          patch :apply_coupon_code, params: { token: old_order.token, coupon_code: gift_card.code.upcase }
          patch :apply_coupon_code, params: { token: order.token, coupon_code: gift_card.code.upcase }

          expect(old_order.reload.gift_card).to eq(gift_card)
          expect(old_order.gift_card_total).to eq(30)

          expect(order.reload.gift_card).to eq(gift_card)
          expect(order.gift_card_total).to eq(20)
        end
      end
    end
  end

  describe '#remove_coupon_code' do
    subject { delete :remove_coupon_code, params: { token: order.token, coupon_code: coupon_code } }

    let(:user) { create(:user) }
    let!(:order) { create(:order_with_line_items, state: 'payment', store: store, bill_address: nil, user: user) }
    let!(:line_item) { create(:line_item, order: order) }
    let!(:shipment) { create(:shipment, order: order) }
    let(:coupon_code) { 'FREESHIP' }
    let!(:promotion) { create(:promotion, name: 'Free shipping', code: coupon_code, stores: [store]) }
    let!(:promotion_action) { Spree::PromotionAction.create(promotion_id: promotion.id, type: 'Spree::Promotion::Actions::FreeShipping') }


    before do
      order.coupon_code = coupon_code
      Spree::PromotionHandler::Coupon.new(order).apply
      order.save!
    end

    it 'removes the promotion' do
      expect(order.reload.promotions).to include(promotion)
      expect(controller).to receive(:track_event).with('coupon_removed', hash_including(order: order, coupon_code: coupon_code))

      subject
      expect(response).to redirect_to spree.checkout_path(order.token)
      expect(order.promotions).not_to include(promotion)
    end

    context 'for a gift card' do
      subject { patch :remove_coupon_code, params: { token: order.token, gift_card: coupon_code } }

      let(:gift_card) { create :gift_card, store: store }
      let(:coupon_code) { gift_card.code.upcase }


      before do
        Spree::GiftCards::Apply.call(order: order, gift_card: gift_card)
      end

      it 'removes the gift card' do
        subject
        expect(order.reload.gift_card).to be nil
        expect(order.gift_card_total).to eq(0)
        expect(order.total_applied_store_credit).to eq(0)
      end
    end
  end

  describe '#remove_missing_items' do
    let(:order) { create(:order_with_line_items, store: store, user: user, line_items_count: 3) }
    let(:line_item) { order.line_items.first }
    let(:line_item_2) { order.line_items.last }

    it 'removes missing items' do
      expect { delete :remove_missing_items, params: { token: order.token, line_item_ids: [line_item.id, line_item_2.id] } }.to change { order.line_items.count }.from(3).to(1)
      expect(response).to redirect_to spree.checkout_path(order.token)
    end
  end

  describe '#load_order' do
    subject do
      get :edit, params: { state: 'address', token: order.token }
    end

    context 'when order is found' do
      context 'when order is completed' do
        before { allow_any_instance_of(Spree::Order).to receive_messages(completed?: true) }

        it 'does not update order tracking attributes' do
          expect{ subject }.not_to change{ order.updated_at }
        end
      end

      context 'when order is editable and not completed' do
        it 'does not update order tracking attributes' do
          expect{ subject }.not_to change{ order.reload.updated_at }
        end
      end
    end
  end

  describe '#apply_store_credit' do
    let!(:order) { create(:order_with_line_items, store: store, user: user) }
    let(:user) { create(:user) }

    let!(:payment_method) { create(:store_credit_payment_method) }
    let!(:store_credit) { create(:store_credit, user: user, amount: 12.34) }

    it 'adds the store credit to the order' do
      post :apply_store_credit, params: { token: order.token }

      expect(response).to redirect_to spree.checkout_path(order.token)

      expect(order.payments.count).to eq(1)
      expect(order.payments.first).to be_checkout
      expect(order.payments.first.source).to eq(store_credit)
      expect(order.payments.first.payment_method).to eq(payment_method)
      expect(order.payments.first.amount).to eq(12.34)
    end
  end

  describe '#remove_store_credit' do
    let!(:order) { create(:order_with_line_items, store: store, user: user) }
    let(:user) { create(:user) }

    let!(:payment_method) { create(:store_credit_payment_method) }
    let!(:store_credit) { create(:store_credit, user: user, amount: 12.34) }

    let!(:store_credit_payment) { create(:store_credit_payment, order: order, source: store_credit, payment_method: payment_method, amount: 12.34) }

    it 'removes the store credit from the order' do
      post :remove_store_credit, params: { token: order.token }

      expect(response).to redirect_to spree.checkout_path(order.token)

      expect(order.reload.payments.count).to eq(1)
      expect(order.payments.first.state).to eq('invalid')
      expect(order.payments.first.source).to eq(store_credit)
      expect(order.payments.first.payment_method).to eq(payment_method)
      expect(order.payments.first.amount).to eq(12.34)
    end
  end
end
