require 'spec_helper'

describe Spree::AddressesController, type: :controller do
  let(:store) { @default_store }
  let(:country) { store.default_country || create(:country_us) }
  let(:state) { create(:state, country: country, name: 'New York', abbr: 'NY') }
  let(:user) { create(:user) }
  let(:order) { create(:order_with_totals, store: store) }
  let(:default_billing) { 'true' }
  let(:default_shipping) { 'true' }

  render_views

  before do
    allow(controller).to receive_messages try_spree_current_user: user
    allow(controller).to receive_messages spree_current_user: user
    allow(controller).to receive_messages current_order: order
    allow_any_instance_of(CanCan::ControllerResource).to receive(:load_resource)
    allow_any_instance_of(CanCan::ControllerResource).to receive(:authorize_resource)
  end

  describe '#create' do
    subject :post_create do
      post :create, params: { address: address_params, default_billing: default_billing, default_shipping: default_shipping }
    end

    context 'when data is valid' do
      let(:address_params) do
        address = build(:address, country: country, state: state)
        address.attributes.except('created_at', 'updated_at', 'quick_checkout')
      end

      it 'returns 302 status code' do
        post_create

        expect(response.status).to eq(302)
      end

      it 'redirects to /account/addresses' do
        post_create

        expect(response).to redirect_to('/account/addresses')
      end

      it 'creates address' do
        expect { post_create }.to change { user.addresses.count }.by(1)
      end

      it 'sets flash message' do
        post_create

        expect(flash[:notice]).to eq Spree.t('address_book.successfully_created')
      end

      context 'default address' do
        let!(:default_address) { create(:address, user: user) }

        before { user.update!(ship_address: default_address, bill_address: default_address) }

        context 'when default_shipping param is false' do
          let(:default_shipping) { nil }

          it 'does not set default shipping address' do
            post_create

            expect(user.reload.shipping_address).to eq(default_address)
            expect(user.billing_address).to eq(Spree::Address.last)
          end
        end

        context 'when default_billing param is false' do
          let(:default_billing) { nil }

          it 'does not set default billing address' do
            post_create

            expect(user.reload.billing_address).to eq(default_address)
            expect(user.shipping_address).to eq(Spree::Address.last)
          end
        end
      end
    end

    context 'when data is not valid' do
      let(:address_params) do
        address = build(:address, country: country, state: state, first_name: nil)
        address.attributes.except('created_at', 'updated_at')
      end

      it 'does not create address' do
        expect { post_create }.not_to change { user.addresses.count }
      end

      it 'returns 422 status code' do
        post_create

        expect(response.status).to eq(422)
      end

      it 'renders address form template' do
        expect(post_create).to render_template(:new)
      end
    end
  end

  describe '#update' do
    subject :put_update do
      put :update, params: { address: address_params, id: address.id }
    end

    before { controller.instance_variable_set(:@address, address) }

    context 'when address is editable' do
      let(:address) { create(:address, country: country, state: state, label: 'label', user: user) }

      context 'with data is valid' do
        let(:address_params) { address.attributes.symbolize_keys.merge(firstname: 'Test') }

        it 'updates address' do
          expect(address.attributes.symbolize_keys.except(:created_at, :updated_at)).not_to match(address_params.except(:created_at, :updated_at))

          put_update

          expect(address.firstname).to eq 'Test'
        end

        it 'sets flash message' do
          put_update

          expect(flash[:notice]).to eq Spree.t('address_book.successfully_updated')
        end

        it 'returns 302 status code' do
          put_update

          expect(response.status).to eq(302)
        end

        it 'redirects to /account/addresses' do
          put_update

          expect(response).to redirect_to(spree.account_addresses_path)
        end
      end

      context 'when data is not valid' do
        let(:address_params) { address.attributes.symbolize_keys.merge(firstname: nil) }

        it 'does not update address' do
          expect { put_update }.not_to change { address }
        end

        it 'renders address form template' do
          expect(put_update).to render_template(:edit)
        end
      end
    end

    context 'when address is not editable' do
      let(:address) { create(:address, country: country, state: state, label: 'label', user: user) }
      let!(:order) { create(:completed_order_with_totals, ship_address: address) }

      context 'with data is valid' do
        let(:address_params) { address.attributes.symbolize_keys.except(:id, :quick_checkout).merge(firstname: 'test', label: '') }

        it 'creates address' do
          expect { put_update }.to change { Spree::Address.count }.by(1)
        end

        it 'sets deleted_at attribute of original address' do
          Timecop.freeze(Time.current) do
            expect(address.deleted_at).to be_nil

            put_update

            expect(address.deleted_at).not_to be nil
          end
        end

        it 'sets flash message' do
          put_update

          expect(flash[:notice]).to eq Spree.t('address_book.successfully_updated')
        end

        it 'returns 302 status code' do
          put_update

          expect(response.status).to eq(302)
        end

        it 'redirects to /account/addresses' do
          put_update

          expect(response).to redirect_to(spree.account_addresses_path)
        end
      end

      context 'when data is not valid' do
        let(:address_params) { address.attributes.symbolize_keys.except(:skip_mainstreet_validation, :quick_checkout).merge(address1: nil) }

        it 'does not create address' do
          expect { put_update }.to change { Spree::Address.count }.by(0)
        end

        it 'renders address form template' do
          expect(put_update).to render_template(:edit)
        end
      end
    end
  end

end

# Separate describe block for security tests - without mocked authorization
describe Spree::AddressesController, 'security', type: :controller do
  let(:store) { @default_store }
  let(:country) { store.default_country || create(:country_us) }
  let(:state) { create(:state, country: country, name: 'New York', abbr: 'NY') }
  let(:user) { create(:user) }

  render_views

  context 'authentication requirement (IDOR vulnerability fix)' do
    let(:guest_address) { create(:address, user_id: nil, country: country, state: state) }

    before do
      allow(controller).to receive_messages try_spree_current_user: nil
      allow(controller).to receive_messages spree_current_user: nil
    end

    describe '#edit' do
      it 'requires authentication and redirects to login' do
        get :edit, params: { id: guest_address.id }
        expect(response).to have_http_status(:redirect)
      end
    end

    describe '#update' do
      let(:address_params) { guest_address.attributes.symbolize_keys.merge(firstname: 'Hacker') }

      it 'requires authentication and redirects to login' do
        put :update, params: { id: guest_address.id, address: address_params }
        expect(response).to have_http_status(:redirect)
      end

      it 'does not update the address when not authenticated' do
        original_firstname = guest_address.firstname
        put :update, params: { id: guest_address.id, address: address_params }
        expect(guest_address.reload.firstname).to eq(original_firstname)
      end
    end

    describe '#destroy' do
      it 'requires authentication and redirects to login' do
        delete :destroy, params: { id: guest_address.id }
        expect(response).to have_http_status(:redirect)
      end

      it 'does not destroy the address when not authenticated' do
        delete :destroy, params: { id: guest_address.id }
        expect(Spree::Address.find_by(id: guest_address.id)).to be_present
      end
    end

    describe '#new' do
      it 'requires authentication and redirects to login' do
        get :new
        expect(response).to have_http_status(:redirect)
      end
    end

    describe '#create' do
      let(:address_params) do
        build(:address, country: country, state: state).attributes.except('created_at', 'updated_at')
      end

      it 'requires authentication and redirects to login' do
        post :create, params: { address: address_params }
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  context 'when authenticated user tries to access another users address' do
    let(:other_user) { create(:user) }
    let(:other_user_address) { create(:address, user: other_user, country: country, state: state) }

    before do
      allow(controller).to receive_messages try_spree_current_user: user
      allow(controller).to receive_messages spree_current_user: user
    end

    describe '#edit' do
      it 'denies access to other users address' do
        get :edit, params: { id: other_user_address.id }
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(spree.root_path)
        expect(flash[:error]).to eq(Spree.t(:authorization_failure))
      end
    end

    describe '#update' do
      let(:address_params) { other_user_address.attributes.symbolize_keys.merge(firstname: 'Hacker') }

      it 'denies update to other users address' do
        put :update, params: { id: other_user_address.id, address: address_params }
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(spree.root_path)
        expect(flash[:error]).to eq(Spree.t(:authorization_failure))
      end

      it 'does not update the address when denied' do
        original_firstname = other_user_address.firstname
        put :update, params: { id: other_user_address.id, address: address_params }
        expect(other_user_address.reload.firstname).to eq(original_firstname)
      end
    end

    describe '#destroy' do
      it 'denies destroy of other users address' do
        delete :destroy, params: { id: other_user_address.id }
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(spree.root_path)
        expect(flash[:error]).to eq(Spree.t(:authorization_failure))
      end

      it 'does not destroy the address when denied' do
        delete :destroy, params: { id: other_user_address.id }
        expect(Spree::Address.find_by(id: other_user_address.id)).to be_present
      end
    end
  end

  context 'when authenticated user accesses their own address' do
    let(:own_address) { create(:address, user: user, country: country, state: state) }

    before do
      allow(controller).to receive_messages try_spree_current_user: user
      allow(controller).to receive_messages spree_current_user: user
    end

    describe '#edit' do
      it 'allows access to own address' do
        get :edit, params: { id: own_address.id }
        expect(response).to have_http_status(:ok)
      end
    end

    describe '#update' do
      let(:address_params) { own_address.attributes.symbolize_keys.merge(firstname: 'Updated') }

      it 'allows update to own address' do
        put :update, params: { id: own_address.id, address: address_params }
        expect(response).to have_http_status(:redirect)
        expect(response).not_to redirect_to(spree.root_path)
        expect(flash[:error]).to be_nil
      end
    end

    describe '#destroy' do
      it 'allows destroy of own address' do
        delete :destroy, params: { id: own_address.id }
        expect(response).to have_http_status(:see_other)
      end
    end
  end
end
