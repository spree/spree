require 'spec_helper'

RSpec.describe Spree::Admin::ShippingCategoriesController, type: :controller do
  stub_authorization!
  render_views

  describe 'GET #index' do
    let!(:shipping_categories) { create_list(:shipping_category, 3) }

    it 'renders the list of shipping categories' do
      get :index

      expect(response).to be_successful
      expect(response).to render_template(:index)

      expect(assigns(:shipping_categories)).to contain_exactly(*shipping_categories)
    end
  end

  describe 'GET #new' do
    it 'renders the new shipping category form' do
      get :new

      expect(response).to be_successful
      expect(response).to render_template(:new)
    end
  end

  describe 'POST #create' do
    let(:shipping_category_params) do
      {
        name: 'Default Category'
      }
    end

    let(:shipping_category) { Spree::ShippingCategory.last }

    it 'creates a new shipping category' do
      post :create, params: { shipping_category: shipping_category_params }

      expect(response).to redirect_to(spree.edit_admin_shipping_category_path(shipping_category))

      expect(shipping_category).to be_persisted
      expect(shipping_category.name).to eq('Default Category')
    end
  end

  describe 'GET #edit' do
    let!(:shipping_category) { create(:shipping_category) }

    it 'renders the edit shipping category form' do
      get :edit, params: { id: shipping_category.to_param }

      expect(response).to be_successful
      expect(response).to render_template(:edit)
    end
  end

  describe 'PUT #update' do
    let!(:shipping_category) { create(:shipping_category, name: 'Default Category') }

    it 'updates the shipping category' do
      put :update, params: { id: shipping_category.to_param, shipping_category: { name: 'Updated Category' } }

      expect(response).to redirect_to(spree.edit_admin_shipping_category_path(shipping_category))
      expect(shipping_category.reload.name).to eq('Updated Category')
    end
  end

  describe 'DELETE #destroy' do
    let!(:shipping_category) { create(:shipping_category) }

    it 'deletes the shipping category' do
      delete :destroy, params: { id: shipping_category.to_param }

      expect(response).to redirect_to(spree.admin_shipping_categories_path)
      expect { shipping_category.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
