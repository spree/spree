require 'spec_helper'

RSpec.describe Spree::Admin::TaxRatesController, type: :controller do
  stub_authorization!
  render_views

  describe 'GET #index' do
    let!(:tax_rates) { create_list(:tax_rate, 3) }

    it 'renders the list of tax rates' do
      get :index

      expect(response).to be_successful
      expect(response).to render_template(:index)

      expect(assigns(:tax_rates)).to contain_exactly(*tax_rates)
    end
  end

  describe 'GET #new' do
    it 'renders the new tax rate form' do
      get :new

      expect(response).to be_successful
      expect(response).to render_template(:new)
    end
  end

  describe 'POST #create' do
    let!(:zone) { create(:zone) }
    let!(:tax_category) { create(:tax_category) }
    let!(:calculator) { Spree::TaxRate.calculators.first }

    let(:tax_rate_params) do
      {
        name: 'General Tax',
        amount: 0.1,
        zone_id: zone.id,
        tax_category_id: tax_category.id,
        calculator_type: calculator.name,
        show_rate_in_label: true,
        included_in_price: true
      }
    end

    let(:tax_rate) { Spree::TaxRate.last }

    it 'creates a new tax rate' do
      post :create, params: { tax_rate: tax_rate_params }

      expect(response).to redirect_to(spree.edit_admin_tax_rate_path(tax_rate))

      expect(tax_rate).to be_persisted
      expect(tax_rate.name).to eq('General Tax')
      expect(tax_rate.amount).to eq(0.1)
      expect(tax_rate.zone).to eq(zone)
      expect(tax_rate.tax_category).to eq(tax_category)
      expect(tax_rate.calculator_type).to eq(calculator.name)
      expect(tax_rate.show_rate_in_label).to eq(true)
      expect(tax_rate.included_in_price).to eq(true)
    end
  end

  describe 'GET #edit' do
    let!(:tax_rate) { create(:tax_rate) }

    it 'renders the edit tax rate form' do
      get :edit, params: { id: tax_rate.id }

      expect(response).to be_successful
      expect(response).to render_template(:edit)
    end
  end

  describe 'PUT #update' do
    let!(:tax_rate) { create(:tax_rate, name: 'General Tax') }

    it 'updates the tax rate' do
      put :update, params: { id: tax_rate.id, tax_rate: { name: 'EU Tax' } }

      expect(response).to redirect_to(spree.edit_admin_tax_rate_path(tax_rate))
      expect(tax_rate.reload.name).to eq('EU Tax')
    end
  end

  describe 'DELETE #destroy' do
    let!(:tax_rate) { create(:tax_rate) }

    it 'deletes the tax rate' do
      delete :destroy, params: { id: tax_rate.id }

      expect(response).to redirect_to(spree.admin_tax_rates_path)
      expect(tax_rate.reload).to be_deleted
    end
  end
end
