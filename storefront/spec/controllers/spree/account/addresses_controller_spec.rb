require 'spec_helper'

describe Spree::Account::AddressesController, type: :controller do
  let(:store) { @default_store }
  let(:user) { create(:user) }
  let(:address) { create(:address, user: user) }

  render_views

  before do
    allow(controller).to receive(:current_store).and_return(store)
    allow(controller).to receive(:spree_login_path).and_return('/login')
  end

  describe '#index' do
    subject { get :index }

    context 'when user is logged in' do
      before do
        allow(controller).to receive_messages try_spree_current_user: user
        allow(controller).to receive_messages spree_current_user: user
      end

      it 'lists addresses for the user' do
        address # create the address
        subject
        expect(assigns(:addresses)).to include(address)
        expect(response).to have_http_status(:ok)
      end

      it 'renders the index template' do
        subject
        expect(response).to render_template(:index)
      end
    end

    context 'when user is not logged in' do
      it 'redirects to login page' do
        expect(subject).to have_http_status(302)
      end
    end
  end
end
