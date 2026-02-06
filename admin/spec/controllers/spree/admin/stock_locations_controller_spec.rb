require 'spec_helper'

RSpec.describe Spree::Admin::StockLocationsController, type: :controller do
  stub_authorization!
  render_views

  describe 'GET #index' do
    let!(:stock_locations) { create_list(:stock_location, 3) }

    it 'renders the list of stock locations' do
      get :index

      expect(response).to be_successful
      expect(response).to render_template(:index)

      expect(assigns(:collection)).to contain_exactly(*stock_locations)
    end
  end

  describe 'GET #new' do
    it 'renders the new stock location form' do
      get :new

      expect(response).to be_successful
      expect(response).to render_template(:new)
      expect(assigns(:stock_location).country).to eq(controller.current_store.default_country)
    end
  end

  describe 'POST #create' do
    let(:stock_location_params) do
      {
        name: 'Main Warehouse',
        address1: '123 Main St',
        city: 'Portland',
        zipcode: '97210',
        state_id: create(:state).id,
        country_id: create(:country).id
      }
    end

    let(:stock_location) { Spree::StockLocation.last }

    it 'creates a new stock location' do
      post :create, params: { stock_location: stock_location_params }

      expect(response).to redirect_to(spree.edit_admin_stock_location_path(stock_location))

      expect(stock_location).to be_persisted
      expect(stock_location.name).to eq('Main Warehouse')
      expect(stock_location.address1).to eq('123 Main St')
      expect(stock_location.city).to eq('Portland')
    end
  end

  describe 'GET #edit' do
    let!(:stock_location) { create(:stock_location) }

    it 'renders the edit stock location form' do
      get :edit, params: { id: stock_location.to_param }

      expect(response).to be_successful
      expect(response).to render_template(:edit)
    end
  end

  describe 'PUT #update' do
    let!(:stock_location) { create(:stock_location, name: 'Main Warehouse') }

    it 'updates the stock location' do
      put :update, params: { id: stock_location.to_param, stock_location: { name: 'New Warehouse' } }

      expect(response).to redirect_to(spree.edit_admin_stock_location_path(stock_location))
      expect(stock_location.reload.name).to eq('New Warehouse')
    end
  end

  describe 'PUT #mark_as_default' do
    let!(:stock_location) { create(:stock_location, default: false) }

    it 'marks the stock location as default' do
      expect {
        put :mark_as_default, params: { id: stock_location.to_param }
      }.to change { stock_location.reload.default }.from(false).to(true)

      expect(response).to redirect_to(spree.admin_stock_locations_path)
    end
  end

  describe 'DELETE #destroy' do
    let!(:stock_location) { create(:stock_location) }

    it 'deletes the stock location' do
      expect {
        delete :destroy, params: { id: stock_location.to_param }
      }.to change(Spree::StockLocation, :count).by(-1)

      expect(response).to redirect_to(spree.admin_stock_locations_path)
    end
  end
end
