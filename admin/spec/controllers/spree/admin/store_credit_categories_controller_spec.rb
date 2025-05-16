require 'spec_helper'

RSpec.describe Spree::Admin::StoreCreditCategoriesController, type: :controller do
  stub_authorization!
  render_views

  describe 'GET #index' do
    let!(:store_credit_categories) { create_list(:store_credit_category, 3) }

    it 'renders the list of store credit categories' do
      get :index

      expect(response).to be_successful
      expect(response).to render_template(:index)

      expect(assigns(:store_credit_categories)).to contain_exactly(*store_credit_categories)
    end
  end

  describe 'GET #new' do
    it 'renders the new store credit category form' do
      get :new

      expect(response).to be_successful
      expect(response).to render_template(:new)
    end
  end

  describe 'POST #create' do
    let(:store_credit_category_params) do
      {
        name: 'Gift Card Category'
      }
    end

    let(:store_credit_category) { Spree::StoreCreditCategory.last }

    it 'creates a new store credit category' do
      post :create, params: { store_credit_category: store_credit_category_params }

      expect(response).to redirect_to(spree.edit_admin_store_credit_category_path(store_credit_category))

      expect(store_credit_category).to be_persisted
      expect(store_credit_category.name).to eq('Gift Card Category')
    end
  end

  describe 'GET #edit' do
    let!(:store_credit_category) { create(:store_credit_category) }

    it 'renders the edit store credit category form' do
      get :edit, params: { id: store_credit_category.id }

      expect(response).to be_successful
      expect(response).to render_template(:edit)
    end
  end

  describe 'PUT #update' do
    let!(:store_credit_category) { create(:store_credit_category, name: 'Gift Card') }

    it 'updates the store credit category' do
      put :update, params: { id: store_credit_category.id, store_credit_category: { name: 'Updated Category' } }

      expect(response).to redirect_to(spree.edit_admin_store_credit_category_path(store_credit_category))
      expect(store_credit_category.reload.name).to eq('Updated Category')
    end
  end

  describe 'DELETE #destroy' do
    let!(:store_credit_category) { create(:store_credit_category) }

    it 'deletes the store credit category' do
      delete :destroy, params: { id: store_credit_category.id }

      expect(response).to redirect_to(spree.admin_store_credit_categories_path)
      expect { store_credit_category.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
