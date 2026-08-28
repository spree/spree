require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::SellersController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:seller) { create(:seller, store: store, name: 'Sparks Audio', status: 'approved') }

  before { request.headers['X-Spree-Api-Key'] = api_key.token }

  describe 'GET #index' do
    it 'lists sellers a shopper can buy from' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].pluck('name')).to eq(['Sparks Audio'])
    end

    # A seller still onboarding, suspended or away has nothing to show a
    # customer, and listing them advertises products that cannot be bought.
    it 'hides sellers who cannot currently sell' do
      create(:seller, store: store, name: 'Not Yet', status: 'pending')
      create(:seller, store: store, name: 'Suspended', status: 'suspended')
      create(:seller, store: store, name: 'Away', status: 'approved',
                      holiday_mode_until: 2.weeks.from_now)

      get :index, as: :json

      expect(json_response['data'].pluck('name')).to eq(['Sparks Audio'])
    end

    it "hides another store's sellers" do
      other = create(:seller, store: create(:store), status: 'approved')

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
      get :show, params: { id: seller.slug }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('Sparks Audio')
    end

    it 'finds a seller by prefixed id' do
      get :show, params: { id: seller.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
    end

    it '404s on a seller who cannot currently sell' do
      hidden = create(:seller, store: store, status: 'pending')

      get :show, params: { id: hidden.slug }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  # A policy body is a whole legal document, so it is opt-in rather than
  # riding along on every seller a listing renders.
  describe 'policies' do
    let!(:policy) { create(:policy, owner: seller, name: 'Returns', body: '<p>Thirty days.</p>') }

    it 'omits policies unless they are asked for' do
      get :show, params: { id: seller.slug }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).not_to have_key('policies')
    end

    it 'includes them on expand' do
      get :show, params: { id: seller.slug, expand: 'policies' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['policies'].pluck('name')).to include('Returns')
      expect(json_response['policies'].first['body_html']).to include('Thirty days.')
    end

    it "does not leak another seller's policies" do
      other_seller = create(:seller, :approved, store: store)
      create(:policy, owner: other_seller, name: 'Someone Else')

      get :show, params: { id: seller.slug, expand: 'policies' }, as: :json

      expect(json_response['policies'].pluck('name')).not_to include('Someone Else')
    end
  end
end
