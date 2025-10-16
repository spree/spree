require 'spec_helper'

describe Spree::Admin::GiftCardsController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }
  let(:user) { create(:user) }
  let(:gift_card) { create(:gift_card, user: user, created_by: admin_user) }

  describe '#index' do
    subject { get :index }

    it 'renders the index template' do
      create_list(:gift_card, 3)
      subject
      expect(response).to render_template(:index)
      expect(response).to have_http_status(:ok)
    end

    context 'when user_id parameter is present' do
      subject { get :index, params: { user_id: user.id } }

      it 'filters gift cards by user' do
        gift_card
        other_gift_card = create(:gift_card)

        subject

        expect(assigns(:collection)).to include(gift_card)
        expect(assigns(:collection)).not_to include(other_gift_card)
      end
    end

    context 'with status filter' do
      let!(:active_gift_card) { create(:gift_card, user: user) }
      let!(:expired_gift_card) { create(:gift_card, :expired) }
      let!(:redeemed_gift_card) { create(:gift_card, :redeemed, user: user) }

      it 'filters by active status' do
        get :index, params: { q: { active: true } }
        expect(assigns(:collection)).to include(active_gift_card)
        expect(assigns(:collection)).not_to include(expired_gift_card, redeemed_gift_card)
      end

      it 'filters by expired status' do
        get :index, params: { q: { expired: true } }
        expect(assigns(:collection)).to include(expired_gift_card)
        expect(assigns(:collection)).not_to include(active_gift_card, redeemed_gift_card)
      end

      it 'filters by redeemed status' do
        get :index, params: { q: { redeemed: true } }
        expect(assigns(:collection)).to include(redeemed_gift_card)
        expect(assigns(:collection)).not_to include(active_gift_card, expired_gift_card)
      end

      context 'with user_id parameter' do
        it 'filters by user' do
          get :index, params: { user_id: user.id }

          expect(assigns(:collection)).to include(active_gift_card, redeemed_gift_card)
          expect(assigns(:collection)).not_to include(expired_gift_card)
        end
      end
    end
  end

  describe '#show' do
    subject { get :show, params: { id: gift_card.id } }

    it 'renders the show template' do
      subject
      expect(response).to render_template(:show)
      expect(response).to have_http_status(:ok)
    end

    it 'assigns the gift card' do
      subject
      expect(assigns(:object)).to eq(gift_card)
    end

    context 'for a redeemed gift card' do
      let!(:order) { create(:order, email: 'user@example.com', user: user, gift_card: gift_card) }
      let(:gift_card) { create(:gift_card, :redeemed, user: user) }

      it 'renders the show template' do
        subject
        expect(response).to render_template(:show)
        expect(response).to have_http_status(:ok)
      end

      it 'assigns the gift card' do
        subject
        expect(assigns(:object)).to eq(gift_card)
      end

      it 'assigns the order' do
        subject
        expect(assigns(:orders)).to eq([order])
      end

      context 'when the order is a guest order' do
        let(:user) { nil }

        it 'renders the show template' do
          subject
          expect(response).to render_template(:show)
          expect(response).to have_http_status(:ok)
        end

        it 'assigns the gift card' do
          subject
          expect(assigns(:object)).to eq(gift_card)
        end

        it 'assigns the order' do
          subject
          expect(assigns(:orders)).to eq([order])
        end
      end
    end
  end

  describe '#new' do
    subject { get :new }

    it 'renders the new template' do
      subject
      expect(response).to render_template(:new)
      expect(response).to have_http_status(:ok)
    end

    it 'assigns a new gift card' do
      subject
      expect(assigns(:object)).to be_a_new(Spree::GiftCard)
    end

    context 'when user_id parameter is present' do
      subject { get :new, params: { user_id: user.id } }

      it 'loads the user' do
        subject
        expect(assigns(:user)).to eq(user)
      end
    end
  end

  describe '#create' do
    let(:valid_params) do
      {
        gift_card: {
          amount: 100,
          currency: 'EUR',
          user_id: user.id,
          expires_at: 1.year.from_now.to_date,
          code: '1234567890'
        }
      }
    end

    subject { post :create, params: valid_params }

    context 'with valid parameters' do
      it 'creates a new gift card' do
        expect { subject }.to change(Spree::GiftCard, :count).by(1)

        gift_card = Spree::GiftCard.last
        expect(gift_card.created_by).to eq(admin_user)
        expect(gift_card.user).to eq(user)
        expect(gift_card.expires_at).to eq(1.year.from_now.to_date)
        expect(gift_card.store).to eq(store)
        expect(gift_card.amount).to eq(100)
        expect(gift_card.code).to eq('1234567890')
        expect(gift_card.state).to eq('active')
      end

      it 'redirects to the gift card show page' do
        subject
        expect(response).to redirect_to(spree.admin_gift_card_path(Spree::GiftCard.last))
      end

      it 'sets a success flash message' do
        subject
        expect(flash[:success]).to be_present
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          gift_card: {
            amount: -100,
            currency: 'EUR'
          }
        }
      end

      subject { post :create, params: invalid_params }

      it 'does not create a gift card' do
        expect { subject }.not_to change(Spree::GiftCard, :count)
      end

      it 'renders the new template' do
        subject
        expect(response).to render_template(:new)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe '#edit' do
    subject { get :edit, params: { id: gift_card.id } }

    it 'renders the edit template' do
      subject
      expect(response).to render_template(:edit)
      expect(response).to have_http_status(:ok)
    end

    it 'assigns the gift card' do
      subject
      expect(assigns(:object)).to eq(gift_card)
    end
  end

  describe '#update' do
    let(:update_params) do
      {
        id: gift_card.id,
        gift_card: {
          amount: 200,
          user_id: user.id,
          expires_at: 1.year.from_now.to_date
        }
      }
    end

    subject { put :update, params: update_params }

    context 'with valid parameters' do
      it 'updates the gift card' do
        subject
        gift_card.reload
        expect(gift_card.amount).to eq(200)
        expect(gift_card.user).to eq(user)
      end

      it 'redirects to the gift card show page' do
        subject
        expect(response).to redirect_to(spree.admin_gift_card_path(gift_card))
      end

      it 'sets a success flash message' do
        subject
        expect(flash[:success]).to be_present
      end
    end

    context 'with invalid parameters' do
      let(:invalid_update_params) do
        {
          id: gift_card.id,
          gift_card: {
            amount: -200
          }
        }
      end

      subject { put :update, params: invalid_update_params }

      it 'does not update the gift card' do
        original_amount = gift_card.amount
        subject
        gift_card.reload
        expect(gift_card.amount).to eq(original_amount)
      end

      it 'renders the edit template' do
        subject
        expect(response).to render_template(:edit)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe '#destroy' do
    let!(:gift_card_to_destroy) { create(:gift_card) }

    subject { delete :destroy, params: { id: gift_card_to_destroy.id } }

    it 'destroys the gift card' do
      expect { subject }.to change(Spree::GiftCard, :count).by(-1)
    end

    it 'redirects to the gift cards index' do
      subject
      expect(response).to redirect_to(spree.admin_gift_cards_path)
    end

    it 'sets a success flash message' do
      subject
      expect(flash[:success]).to be_present
    end

    context 'when user_id parameter is present' do
      let!(:user_gift_card) { create(:gift_card, user: user) }

      subject { delete :destroy, params: { id: user_gift_card.id, user_id: user.id } }

      it 'redirects to the user page' do
        subject
        expect(response).to redirect_to(spree.admin_user_path(user))
      end
    end
  end
end
