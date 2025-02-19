require 'spec_helper'

describe Spree::Account::WishedItemsController, type: :controller do
  let(:store) { Spree::Store.default }
  let(:variant) { create(:variant, price: 19.99) }
  let(:format) { :html }

  before do
    allow(controller).to receive(:current_store).and_return(store)
    allow(controller).to receive(:spree_login_path).and_return('/login')
  end

  describe '#create' do
    subject { post :create, params: { wished_item: { variant_id: variant.id } }, format: format }

    context 'when an item is already added to a wishlist' do
      let(:wishlist) { create(:wishlist, user: user, store: store) }
      let(:user) { create(:user) }

      let!(:wished_item) { create(:wished_item, variant: variant, wishlist: wishlist) }

      before do
        allow(controller).to receive(:current_store).and_return(store)
        allow(controller).to receive_messages try_spree_current_user: user
        allow(controller).to receive_messages spree_current_user: user
        allow(controller).to receive(:current_wishlist).and_return(wishlist)
      end

      it 'responds with an error' do
        expect { subject }.to_not change(Spree::WishedItem, :count)
        expect(flash[:error]).to eq('You already added this item to your wishlist')
      end
    end
  end

  describe '#destroy' do
    let(:user) { create(:user) }
    let(:wishlist) { create(:wishlist, user: user, store: store) }
    let!(:wished_item) { create(:wished_item, variant: variant, wishlist: wishlist) }

    subject { delete :destroy, params: { id: variant.id }, format: format }

    context 'when user is logged in' do
      before do
        allow(controller).to receive(:current_store).and_return(store)
        allow(controller).to receive_messages try_spree_current_user: user
        allow(controller).to receive_messages spree_current_user: user
        allow(controller).to receive(:current_wishlist).and_return(wishlist)
      end

      it 'removes wished item' do
        expect { subject }.to change { wishlist.wished_items.count }.by(-1)

        expect(response).to have_http_status(302)
      end

      context 'with turbo_stream format' do
        render_views
        let(:format) { :turbo_stream }

        it 'responds successfully' do
          subject

          expect(response).to have_http_status(200)
        end
      end
    end

    context 'when user is not logged in' do
      it 'redirects to login page' do
        expect(subject).to have_http_status(302)
      end
    end

    context 'when an item is already removed from the wishlist' do
      let(:wishlist) { create(:wishlist, user: user, store: store) }
      let(:user) { create(:user) }

      before do
        wished_item.destroy!

        allow(controller).to receive(:current_store).and_return(store)
        allow(controller).to receive_messages try_spree_current_user: user
        allow(controller).to receive_messages spree_current_user: user
        allow(controller).to receive(:current_wishlist).and_return(wishlist)
      end

      it 'responds with an error' do
        expect { subject }.to_not change(Spree::WishedItem, :count)
        expect(flash[:error]).to eq('You already removed this item from your wishlist')
      end
    end
  end
end
