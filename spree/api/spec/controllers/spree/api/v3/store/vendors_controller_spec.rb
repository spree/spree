require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::VendorsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:vendor) { create(:vendor, store: store, name: 'Sparks Audio', status: 'approved') }

  before { request.headers['X-Spree-Api-Key'] = api_key.token }

  describe 'GET #index' do
    it 'lists sellers a shopper can buy from' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].pluck('name')).to eq(['Sparks Audio'])
    end

    # A vendor still onboarding, suspended or away has nothing to show a
    # customer, and listing them advertises products that cannot be bought.
    it 'hides sellers who cannot currently sell' do
      create(:vendor, store: store, name: 'Not Yet', status: 'pending')
      create(:vendor, store: store, name: 'Suspended', status: 'suspended')
      create(:vendor, store: store, name: 'Away', status: 'approved',
                      holiday_mode_until: 2.weeks.from_now)

      get :index, as: :json

      expect(json_response['data'].pluck('name')).to eq(['Sparks Audio'])
    end

    it "hides another store's sellers" do
      other = create(:vendor, store: create(:store), status: 'approved')

      get :index, as: :json

      expect(json_response['data'].pluck('id')).not_to include(other.prefixed_id)
    end

    # The storefront gets the profile and nothing about how the marketplace
    # runs the seller.
    it 'exposes no operational, settlement or contact data' do
      get :index, as: :json

      expect(json_response['data'].first.keys).to match_array(
        %w[id name slug about about_html logo_url square_logo_url cover_photo_url]
      )
    end
  end

  describe 'GET #show' do
    it 'finds a seller by slug' do
      get :show, params: { id: vendor.slug }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('Sparks Audio')
    end

    it 'finds a seller by prefixed id' do
      get :show, params: { id: vendor.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
    end

    it '404s on a seller who cannot currently sell' do
      hidden = create(:vendor, store: store, status: 'pending')

      get :show, params: { id: hidden.slug }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
