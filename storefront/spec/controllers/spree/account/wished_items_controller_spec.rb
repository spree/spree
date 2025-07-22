require 'spec_helper'

describe Spree::Account::WishedItemsController, type: :controller do
  let(:store) { @default_store }
  let(:variant) { create(:variant, price: 19.99) }
  let(:format) { :html }
  let(:user) { create(:user) }
  let(:wishlist) { create(:wishlist, user: user, store: store, is_default: true) }

  render_views

  before do
    allow(controller).to receive(:current_store).and_return(store)
    allow(controller).to receive(:spree_login_path).and_return('/login')
    allow(controller).to receive_messages try_spree_current_user: user
    allow(controller).to receive(:current_wishlist).and_return(wishlist)
  end

  describe '#create' do
    subject { post :create, params: { wished_item: { variant_id: variant.id } }, format: format }

    it 'adds a wished item to the wishlist' do
      expect { subject }.to change(Spree::WishedItem, :count).by(1)
    end

    it 'tracks the event' do
      expect(controller).to receive(:track_event).with('product_added_to_wishlist', variant: variant)
      subject
    end

    context 'when an item is already added to a wishlist' do
      let!(:wished_item) { create(:wished_item, variant: variant, wishlist: wishlist) }

      it 'responds with an error' do
        expect { subject }.to_not change(Spree::WishedItem, :count)
        expect(flash[:error]).to eq('You already added this item to your wishlist')
      end
    end
  end

  describe '#destroy' do
    let!(:wished_item) { create(:wished_item, variant: variant, wishlist: wishlist) }

    subject { delete :destroy, params: { id: variant.id }, format: format }

    context 'when user is logged in' do
      it 'removes wished item' do
        expect { subject }.to change { wishlist.wished_items.count }.by(-1)

        expect(response).to have_http_status(302)
      end

      it 'tracks the event' do
        expect(controller).to receive(:track_event).with('product_removed_from_wishlist', variant: variant)
        subject
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
      before do
        allow(controller).to receive(:try_spree_current_user).and_return(nil)
      end

      it 'redirects to login page' do
        expect(subject).to have_http_status(302)
      end
    end

    context 'when an item is already removed from the wishlist' do
      before do
        wished_item.destroy!
      end

      it 'responds with an error' do
        expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
