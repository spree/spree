require 'spec_helper'

RSpec.describe Spree::Admin::StoreCreditsController, type: :controller do
  render_views

  let(:admin_user) { create(:admin_user) }
  let(:user) { create(:user) }

  before do
    allow(controller).to receive(:try_spree_current_user).and_return(admin_user)
  end

  describe 'GET #index' do
    let!(:store_credits) { create_list(:store_credit, 3, user: user) }
    let!(:other_store_credits) { create_list(:store_credit, 3) }

    it 'renders the list of store credits' do
      get :index, params: { user_id: user.id }

      expect(response).to be_successful
      expect(response).to render_template(:index)

      expect(assigns(:collection)).to contain_exactly(*store_credits)
    end
  end

  describe 'GET #show' do
    let(:store_credit) { create(:store_credit, user: user) }
    let!(:store_credit_events) { create_list(:store_credit_auth_event, 3, store_credit: store_credit) }

    it 'renders the store credit show page' do
      get :show, params: { user_id: user.id, id: store_credit.id }

      expect(response).to be_successful
      expect(response).to render_template(:show)
    end
  end

  describe 'GET #new' do
    it 'renders the new store credit form' do
      get :new, params: { user_id: user.id }

      expect(response).to be_successful
      expect(response).to render_template(:new)
    end
  end

  describe 'POST #create' do
    subject { post :create, params: { user_id: user.id, store_credit: store_credit_params } }

    let(:store_credit_params) { { amount: 100, currency: 'USD' } }

    let(:store_credit) { user.store_credits.last }

    it 'creates a new user store credit' do
      expect { subject }.to change { user.reload.store_credits.count }.by(1)

      expect(response).to redirect_to(spree.admin_user_path(user))

      expect(store_credit.amount).to eq(100)
      expect(store_credit.currency).to eq('USD')
      expect(store_credit.created_by).to eq(admin_user)
    end

    context 'when the store credit is not valid' do
      let(:store_credit_params) { { amount: 100 } }

      it 'does not create a new store credit' do
        expect { subject }.not_to change { user.reload.store_credits.count }

        expect(response).to be_unprocessable
        expect(response).to render_template(:new)

        expect(flash[:error]).to eq(Spree.t('store_credit.errors.unable_to_create'))
      end
    end
  end

  describe 'GET #edit' do
    let(:store_credit) { create(:store_credit, user: user) }

    it 'renders the edit store credit form' do
      get :edit, params: { user_id: user.id, id: store_credit.id }

      expect(response).to be_successful
      expect(response).to render_template(:edit)
    end
  end

  describe 'PUT #update' do
    subject { put :update, params: { user_id: user.id, id: store_credit.id, store_credit: store_credit_params } }

    let(:store_credit) { create(:store_credit, user: user) }
    let(:store_credit_params) { { amount: 200 } }

    it 'updates the store credit' do
      expect { subject }.to change { store_credit.reload.amount }.to(200)

      expect(response).to redirect_to(spree.admin_user_store_credit_path(user, store_credit))
    end

    context 'when the store credit is not valid' do
      let(:store_credit_params) { { amount: 200, currency: nil } }

      it 'does not update the store credit' do
        expect { subject }.not_to change { store_credit.reload.amount }

        expect(response).to be_unprocessable
        expect(response).to render_template(:edit)

        expect(flash[:error]).to eq(Spree.t('store_credit.errors.unable_to_update'))
      end
    end
  end

  describe 'DELETE #destroy' do
    subject { delete :destroy, params: { user_id: user.id, id: store_credit.id } }

    let(:store_credit) { create(:store_credit, user: user) }

    it 'deletes the store credit' do
      subject

      expect(response).to redirect_to(spree.admin_user_path(user))
      expect(store_credit.reload).to be_deleted
    end

    context 'when the store credit is used' do
      let(:store_credit) { create(:store_credit, user: user, amount: 100, amount_used: 50) }

      it 'does not delete the store credit' do
        expect { subject }.to raise_error(Spree::Admin::StoreCreditError, Spree.t('store_credit.errors.cannot_change_used_store_credit'))

        expect(store_credit.reload).not_to be_deleted
      end
    end
  end
end
