require 'spec_helper'

describe Spree::AddressesController, type: :controller do
  let(:store) { Spree::Store.default }
  let(:country) { store.default_country }
  let(:state) { country.states.first }
  let(:token) { 'some_token' }
  let(:user) { create(:user) }
  let(:order) { create(:order_with_totals, store: store) }

  subject :post_create do
    post :create, params: { address: address_params }
  end

  before do
    allow(controller).to receive_messages try_spree_current_user: user
    allow(controller).to receive_messages spree_current_user: user
    allow(controller).to receive_messages current_order: order
    allow_any_instance_of(ActionDispatch::Routing::RoutesProxy).to receive(:account_path).and_return('/account')
    allow_any_instance_of(CanCan::ControllerResource).to receive(:load_resource)
    allow_any_instance_of(CanCan::ControllerResource).to receive(:authorize_resource)
  end

  describe '#create' do
    context 'when data is valid' do
      let(:address_params) do
        address = build(:address, country: country, state: state)
        address.attributes.except('created_at', 'updated_at')
      end

      it 'returns 302 status code' do
        post_create

        expect(response.status).to eq(302)
      end

      it 'redirects to /account' do
        post_create

        expect(response).to redirect_to('/account')
      end

      it 'creates address' do
        expect{ post_create }.to change { Spree::Address.count }.by(1)
      end

      it 'sets flash message' do
        post_create

        expect(flash[:notice]).to eq I18n.t(:successfully_created, scope: :address_book)
      end
    end

    context 'when data is not valid' do
      let(:address_params) do
        address = build(:address, country: country, state: state, first_name: nil)
        address.attributes.except('created_at', 'updated_at')
      end

      it 'returns 200 status code' do
        post_create

        expect(response.status).to eq(200)
      end

      it 'renders address form template' do
        expect(post_create).to render_template(:new)
      end
    end
  end

  describe '#create' do
    context 'when data is valid' do
      let(:address_params) do
        address = build(:address, country: country, state: state)
        address.attributes.except('created_at', 'updated_at')
      end

      it 'returns 302 status code' do
        post_create

        expect(response.status).to eq(302)
      end

      it 'redirects to /account' do
        post_create

        expect(response).to redirect_to('/account')
      end

      it 'creates address' do
        expect{ post_create }.to change { Spree::Address.count }.by(1)
      end

      it 'sets flash message' do
        post_create

        expect(flash[:notice]).to eq I18n.t(:successfully_created, scope: :address_book)
      end
    end

    context 'when data is not valid' do
      let(:address_params) do
        address = build(:address, country: country, state: state, first_name: nil)
        address.attributes.except('created_at', 'updated_at')
      end

      it 'returns 200 status code' do
        post_create

        expect(response.status).to eq(200)
      end

      it 'renders address form template' do
        expect(post_create).to render_template(:new)
      end
    end
  end
end