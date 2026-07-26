require 'spec_helper'

RSpec.describe Spree::Admin::UserAddressesController, type: :controller do
  stub_authorization!
  render_views

  let(:user) { create(:user) }
  let!(:address) { create(:address, user: user) }
  let!(:other_address) { create(:address, user: create(:user)) }

  describe 'GET #index' do
    context 'as a Turbo Frame request' do
      before { request.headers['Turbo-Frame'] = 'addresses' }

      it 'renders the addresses table scoped to the user' do
        get :index, params: { user_id: user.to_param }

        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:index)
        expect(assigns(:collection)).to contain_exactly(address)
        expect(assigns(:user)).to eq(user)
      end
    end

    context 'as a full-page request (not a Turbo Frame)' do
      it 'redirects to the user page' do
        get :index, params: { user_id: user.to_param }

        expect(response).to redirect_to(spree.admin_user_path(user))
      end
    end

    context 'when the user cannot be found' do
      it 'redirects to the users list' do
        get :index, params: { user_id: 'cus_nonexistent' }

        expect(response).to redirect_to(spree.admin_users_path)
      end
    end
  end
end
