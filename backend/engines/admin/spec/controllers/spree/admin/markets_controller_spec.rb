require 'spec_helper'

RSpec.describe Spree::Admin::MarketsController, type: :controller do
  render_views
  stub_authorization!

  let(:store) { @default_store }
  let(:country) { create(:country) }

  describe 'GET #index' do
    let!(:market) { create(:market, store: store, countries: [country]) }

    it 'returns a successful response' do
      get :index
      expect(response).to be_successful
    end

    it 'assigns @collection' do
      get :index
      expect(assigns(:collection)).to include(market)
    end
  end

  describe 'GET #new' do
    it 'returns a successful response' do
      get :new
      expect(response).to be_successful
    end

    it 'assigns a new market' do
      get :new
      expect(assigns(:market)).to be_a_new(Spree::Market)
    end

    it 'loads countries' do
      country
      get :new
      expect(assigns(:countries)).to include(country)
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        market: {
          name: 'North America',
          country_ids: [country.id],
          currency: 'USD',
          default_locale: 'en'
        }
      }
    end

    it 'creates a new market' do
      expect {
        post :create, params: valid_params
      }.to change(Spree::Market, :count).by(1)
    end

    it 'redirects after create' do
      post :create, params: valid_params
      expect(response).to have_http_status(:redirect)
    end

    context 'with invalid params' do
      it 'renders new' do
        post :create, params: { market: { name: '' } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'GET #edit' do
    let(:market) { create(:market, store: store, countries: [country]) }

    it 'returns a successful response' do
      get :edit, params: { id: market.to_param }
      expect(response).to be_successful
    end

    it 'loads countries' do
      get :edit, params: { id: market.to_param }
      expect(assigns(:countries)).to include(country)
    end
  end

  describe 'PUT #update' do
    let(:market) { create(:market, store: store, countries: [country]) }

    it 'updates the market' do
      put :update, params: { id: market.to_param, market: { name: 'Updated Name' } }
      expect(market.reload.name).to eq('Updated Name')
    end

    it 'redirects after update' do
      put :update, params: { id: market.to_param, market: { name: 'Updated Name' } }
      expect(response).to have_http_status(:redirect)
    end

    context 'with invalid params' do
      it 'renders edit' do
        put :update, params: { id: market.to_param, market: { name: '' } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:market) { create(:market, store: store, countries: [country]) }

    it 'soft deletes the market' do
      delete :destroy, params: { id: market.to_param }
      expect(market.reload.deleted_at).to be_present
    end

    it 'redirects to index' do
      delete :destroy, params: { id: market.to_param }
      expect(response).to have_http_status(:redirect)
    end
  end
end
