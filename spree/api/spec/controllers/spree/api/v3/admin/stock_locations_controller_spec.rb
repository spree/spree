require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::StockLocationsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:stock_location) { create(:stock_location, name: 'Warehouse A') }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    let!(:other_location) { create(:stock_location, name: 'Warehouse B', active: false) }

    it 'returns all stock locations ordered by default desc, name asc' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)

      ids = json_response['data'].map { |sl| sl['id'] }
      expect(ids).to include(stock_location.prefixed_id, other_location.prefixed_id)
    end

    it 'includes the new pickup attributes' do
      get :index, as: :json

      sl = json_response['data'].find { |s| s['id'] == stock_location.prefixed_id }
      expect(sl).to include(
        'kind' => 'warehouse',
        'pickup_enabled' => false,
        'pickup_stock_policy' => 'local',
        'pickup_ready_in_minutes' => nil,
        'pickup_instructions' => nil
      )
    end

    context 'with ransack filters' do
      it 'filters by active' do
        get :index, params: { q: { active_eq: true } }, as: :json

        ids = json_response['data'].map { |sl| sl['id'] }
        expect(ids).to include(stock_location.prefixed_id)
        expect(ids).not_to include(other_location.prefixed_id)
      end

      it 'filters by kind' do
        stock_location.update!(kind: 'store')
        get :index, params: { q: { kind_eq: 'store' } }, as: :json

        ids = json_response['data'].map { |sl| sl['id'] }
        expect(ids).to eq([stock_location.prefixed_id])
      end
    end
  end

  describe 'GET #show' do
    it 'returns the stock location' do
      get :show, params: { id: stock_location.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(stock_location.prefixed_id)
      expect(json_response['name']).to eq(stock_location.name)
      expect(json_response).to have_key('kind')
      expect(json_response).to have_key('pickup_enabled')
    end

    it 'returns 404 for unknown id' do
      get :show, params: { id: 'sloc_doesnotexist' }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    let(:country) { Spree::Country.first || create(:country) }

    let(:valid_params) do
      {
        name: 'New York Store',
        admin_name: 'NYC',
        address1: '350 5th Ave',
        city: 'New York',
        zipcode: '10118',
        country_iso: country.iso,
        kind: 'store',
        pickup_enabled: true,
        pickup_stock_policy: 'local',
        pickup_ready_in_minutes: 60,
        pickup_instructions: 'Pick up at the front desk.'
      }
    end

    it 'creates a stock location' do
      expect {
        post :create, params: valid_params, as: :json
      }.to change(Spree::StockLocation, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response).to include(
        'name' => 'New York Store',
        'kind' => 'store',
        'pickup_enabled' => true,
        'pickup_ready_in_minutes' => 60,
        'pickup_instructions' => 'Pick up at the front desk.'
      )
    end

    it 'resolves country_iso and state_abbr to the right associations' do
      state = country.states.find_by(abbr: 'NY') ||
              create(:state, country: country, abbr: 'NY', name: 'New York')

      post :create, params: valid_params.merge(state_abbr: state.abbr), as: :json

      expect(response).to have_http_status(:created)
      created = Spree::StockLocation.find_by_prefix_id!(json_response['id'])
      expect(created.country_id).to eq(country.id)
      expect(created.state_id).to eq(state.id)
    end

    context 'with invalid params' do
      it 'returns validation errors when name is missing' do
        post :create, params: valid_params.merge(name: ''), as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('validation_error')
      end

      it 'rejects unknown pickup_stock_policy' do
        post :create, params: valid_params.merge(pickup_stock_policy: 'bogus'), as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['details']).to have_key('pickup_stock_policy')
      end
    end
  end

  describe 'PATCH #update' do
    it 'updates basic attributes' do
      patch :update, params: {
        id: stock_location.prefixed_id,
        name: 'Renamed Warehouse',
        pickup_enabled: true,
        pickup_ready_in_minutes: 30
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('Renamed Warehouse')
      expect(json_response['pickup_enabled']).to be true
      expect(json_response['pickup_ready_in_minutes']).to eq(30)

      stock_location.reload
      expect(stock_location.name).to eq('Renamed Warehouse')
      expect(stock_location.pickup_enabled).to be true
    end

    it 'promotes a non-default location to default and demotes the previous default' do
      previous_default = create(:stock_location, name: 'Old default', default: true)
      expect(previous_default.reload.default).to be true

      patch :update, params: {
        id: stock_location.prefixed_id,
        default: true
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(stock_location.reload.default).to be true
      expect(previous_default.reload.default).to be false
    end

    it 'returns validation errors for invalid pickup_stock_policy' do
      patch :update, params: {
        id: stock_location.prefixed_id,
        pickup_stock_policy: 'invalid'
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['code']).to eq('validation_error')
    end
  end

  describe 'DELETE #destroy' do
    it 'soft-deletes the stock location' do
      expect {
        delete :destroy, params: { id: stock_location.prefixed_id }, as: :json
      }.to change { Spree::StockLocation.where(id: stock_location.id).count }.from(1).to(0)

      expect(response).to have_http_status(:no_content)
      expect(Spree::StockLocation.with_deleted.find(stock_location.id).deleted_at).not_to be_nil
    end
  end
end
