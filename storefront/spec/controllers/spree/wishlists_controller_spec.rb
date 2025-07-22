require 'spec_helper'

describe Spree::WishlistsController, type: :controller do
  let(:store) { @default_store }
  let(:user) { create(:user) }
  let(:wishlist) { create(:wishlist, user: user, store: store, is_default: true) }
  let(:variant) { create(:variant) }
  let!(:wished_item) { create(:wished_item, variant: variant, wishlist: wishlist) }

  render_views

  before do
    allow(controller).to receive(:current_store).and_return(store)
    allow(controller).to receive(:spree_login_path).and_return('/login')
  end

  describe '#show' do
    context 'when wishlist id and token are provided' do
      subject { get :show, params: { id: wishlist.id, token: wishlist.token } }

      it 'finds the wishlist by id and token' do
        subject
        expect(assigns(:wishlist)).to eq wishlist
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when user is logged in' do
      before do
        allow(controller).to receive_messages try_spree_current_user: user
        allow(controller).to receive_messages spree_current_user: user
      end

      subject { get :show }

      it 'finds the default wishlist for current user' do
        subject
        expect(assigns(:wishlist)).to eq wishlist
        expect(response).to have_http_status(:ok)
      end

      it 'loads wished items' do
        subject
        expect(assigns(:wished_items)).to include(wished_item)
      end
    end

    context 'when user is not logged in' do
      subject { get :show }

      it 'redirects to login page' do
        expect(subject).to have_http_status(302)
      end
    end
  end
end
