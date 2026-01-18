require 'spec_helper'

describe Spree::Account::GiftCardsController, type: :controller do
  render_views

  let(:store) { @default_store }
  let(:user) { create(:user) }

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

      it 'renders the index template' do
        subject
        expect(response).to render_template(:index)
        expect(response).to have_http_status(:ok)
      end

      context 'when user has no gift cards' do
        it 'assigns an empty array to @gift_cards' do
          subject
          expect(assigns(:gift_cards)).to eq([])
        end
      end

      context 'when user has gift cards' do
        let!(:gift_card) { create(:gift_card, user: user) }
        let!(:gift_card_2) { create(:gift_card, user: user) }

        it 'assigns the gift cards to gift_cards in descending order' do
          subject
          expect(assigns(:gift_cards)).to eq([gift_card_2, gift_card])
        end
      end

      describe 'pagination' do
        let!(:gift_cards) { create_list(:gift_card, 30, user: user) }

        context 'with Pagy (default)' do
          before { Spree::Storefront::Config[:use_kaminari_pagination] = false }

          it 'paginates gift cards with Pagy' do
            subject
            expect(assigns(:pagy)).to be_a(Pagy::Offset)
            expect(assigns(:gift_cards).size).to eq(25)
          end

          it 'returns next page' do
            get :index, params: { page: 2 }
            expect(assigns(:pagy).page).to eq(2)
            expect(assigns(:gift_cards).size).to eq(5)
          end
        end

        context 'with Kaminari' do
          before { Spree::Storefront::Config[:use_kaminari_pagination] = true }
          after { Spree::Storefront::Config[:use_kaminari_pagination] = false }

          it 'paginates gift cards with Kaminari' do
            subject
            expect(assigns(:pagy)).to be_nil
            expect(assigns(:gift_cards)).to respond_to(:total_pages)
            expect(assigns(:gift_cards).size).to eq(25)
          end

          it 'returns next page' do
            get :index, params: { page: 2 }
            expect(assigns(:gift_cards).current_page).to eq(2)
            expect(assigns(:gift_cards).size).to eq(5)
          end
        end
      end
    end

    context 'when user is not logged in' do
      it 'redirects to the login page' do
        subject
        expect(response).to have_http_status(:found)
      end
    end
  end
end
