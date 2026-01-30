require 'spec_helper'

RSpec.describe Spree::Admin::TaxCategoriesController, type: :controller do
  stub_authorization!
  render_views

  describe 'GET #index' do
    let!(:tax_categories) { create_list(:tax_category, 3) }

    it 'renders the list of tax categories' do
      get :index

      expect(response).to be_successful
      expect(response).to render_template(:index)

      expect(assigns(:tax_categories)).to contain_exactly(*tax_categories)
    end
  end

  describe 'GET #new' do
    it 'renders the new tax category form' do
      get :new

      expect(response).to be_successful
      expect(response).to render_template(:new)
    end
  end

  describe 'POST #create' do
    let(:tax_category_params) do
      {
        name: 'General Category',
        description: 'General tax category',
        tax_code: 'GEN',
        is_default: true
      }
    end

    let(:tax_category) { Spree::TaxCategory.last }

    it 'creates a new tax category' do
      expect {
        post :create, params: { tax_category: tax_category_params }
      }.to change(Spree::TaxCategory, :count).by(1)

      expect(response).to redirect_to(spree.edit_admin_tax_category_path(tax_category))

      expect(tax_category).to be_persisted
      expect(tax_category.name).to eq('General Category')
      expect(tax_category.description).to eq('General tax category')
      expect(tax_category.tax_code).to eq('GEN')
      expect(tax_category.is_default).to be true
    end
  end

  describe 'GET #edit' do
    let!(:tax_category) { create(:tax_category) }

    it 'renders the edit tax category form' do
      get :edit, params: { id: tax_category.to_param }

      expect(response).to be_successful
      expect(response).to render_template(:edit)
    end
  end

  describe 'PUT #update' do
    let!(:tax_category) { create(:tax_category, name: 'General Category') }

    it 'updates the tax category' do
      put :update, params: { id: tax_category.to_param, tax_category: { name: 'Updated Category' } }

      expect(response).to redirect_to(spree.edit_admin_tax_category_path(tax_category))
      expect(tax_category.reload.name).to eq('Updated Category')
    end
  end

  describe 'DELETE #destroy' do
    let!(:tax_category) { create(:tax_category) }

    it 'deletes the tax category' do
      delete :destroy, params: { id: tax_category.to_param }

      expect(response).to redirect_to(spree.admin_tax_categories_path)
      expect(tax_category.reload).to be_deleted
    end
  end
end
