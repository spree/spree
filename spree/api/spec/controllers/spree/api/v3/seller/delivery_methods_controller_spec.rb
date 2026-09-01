require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::DeliveryMethodsController, type: :controller do
  render_views

  include_context 'API v3 Seller'

  let(:seller_role) do
    create(:role, name: 'Seller', resource: seller, permissions: %w[read_products write_delivery_methods])
  end

  let(:token) do
    Spree::Api::V3::TestingSupport.generate_jwt(
      seller_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER
    )
  end

  let(:profile) { store.default_delivery_profile || create(:delivery_profile, store: store) }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'GET #index' do
    let!(:own_method) { create(:delivery_method, store: store, seller: seller, name: 'My courier') }
    let!(:shared_method) { create(:delivery_method, store: store, available_to_sellers: true, name: 'Marketplace post') }
    let!(:unshared_method) { create(:delivery_method, store: store, name: 'Operator only') }
    let!(:rivals_method) do
      create(:delivery_method, store: store, seller: create(:seller, store: store), name: 'A rival courier')
    end

    it "lists the seller's own methods and the marketplace ones shared with them" do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].pluck('name')).to contain_exactly('My courier', 'Marketplace post')
    end

    it 'marks a shared marketplace method as one the seller cannot change' do
      get :index, as: :json

      rows = json_response['data'].index_by { |row| row['name'] }
      expect(rows['My courier']['editable']).to be true
      expect(rows['Marketplace post']['editable']).to be false
    end

    it "never lists another seller's method" do
      get :index, as: :json

      expect(json_response['data'].pluck('id')).not_to include(rivals_method.prefixed_id)
    end

    it "leaves out another store's methods" do
      elsewhere = create(:delivery_method, store: create(:store), available_to_sellers: true)

      get :index, as: :json

      expect(json_response['data'].pluck('id')).not_to include(elsewhere.prefixed_id)
    end

    context 'without read_delivery_methods' do
      let(:seller_role) { create(:role, name: 'Seller', resource: seller, permissions: %w[read_orders]) }

      it 'is forbidden' do
        get :index, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        name: 'Next day',
        delivery_profile_id: profile.prefixed_id,
        calculator_type: 'Spree::Calculator::Shipping::FlatRate',
        calculator_preferences: { amount: '9.99', currency: 'USD' }
      }
    end

    it "creates the method as the seller's own, whatever the payload says" do
      post :create, params: valid_params, as: :json

      expect(response).to have_http_status(:created)
      expect(Spree::DeliveryMethod.find_by(name: 'Next day').seller).to eq(seller)
    end

    it 'prices it with the calculator the seller chose' do
      post :create, params: valid_params, as: :json

      calculator = Spree::DeliveryMethod.find_by(name: 'Next day').calculator
      expect(calculator.preferred_amount).to eq(9.99)
    end

    # Carriers stay the marketplace's, so neither provider is writable —
    # `permit` drops them and the row is born on the defaults.
    it 'ignores an attempt to pick a carrier' do
      post :create, params: valid_params.merge(
        rate_provider: 'Spree::DeliveryRateProvider::Internal',
        fulfillment_provider: 'Spree::FulfillmentProvider::Digital'
      ), as: :json

      expect(response).to have_http_status(:created)
      expect(Spree::DeliveryMethod.find_by(name: 'Next day').fulfillment_provider).
        to eq(Spree::DeliveryMethod::DEFAULT_FULFILLMENT_PROVIDER)
    end

    it 'refuses a calculator this store does not offer' do
      post :create, params: valid_params.merge(calculator_type: 'NoSuchCalculator'), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['details']).to have_key('calculator_type')
    end

    it 'refuses to share the seller’s own method with the marketplace' do
      post :create, params: valid_params.merge(available_to_sellers: true), as: :json

      expect(response).to have_http_status(:created)
      expect(Spree::DeliveryMethod.find_by(name: 'Next day').available_to_sellers).to be false
    end

    it "404s on another store's delivery profile" do
      elsewhere = create(:delivery_profile, store: create(:store))

      post :create, params: valid_params.merge(delivery_profile_id: elsewhere.prefixed_id), as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'accepts an eligibility rule the seller may set' do
      post :create, params: valid_params.merge(
        rules: [{ type: 'item_total_rule', preferences: { amount_min: '50', currency: 'USD' } }]
      ), as: :json

      expect(response).to have_http_status(:created)
      expect(Spree::DeliveryMethod.find_by(name: 'Next day').delivery_method_rules.count).to eq(1)
    end

    # Channel rules segment the marketplace's own traffic; refused rather
    # than dropped, so a seller is never told a rule saved that did not.
    it 'refuses a rule kind this branch does not offer' do
      post :create, params: valid_params.merge(
        rules: [{ type: 'channel_rule', preferences: { channel_ids: [] } }]
      ), as: :json

      expect(response).to have_http_status(:not_found)
    end

    context 'without write_delivery_methods' do
      let(:seller_role) { create(:role, name: 'Seller', resource: seller, permissions: %w[read_delivery_methods]) }

      it 'is forbidden' do
        post :create, params: valid_params, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PATCH #update' do
    let!(:own_method) { create(:delivery_method, store: store, seller: seller, name: 'My courier') }

    it "renames the seller's own method" do
      patch :update, params: { id: own_method.prefixed_id, name: 'Renamed' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(own_method.reload.name).to eq('Renamed')
    end

    it "404s on a marketplace method the operator merely shares" do
      shared = create(:delivery_method, store: store, available_to_sellers: true)

      patch :update, params: { id: shared.prefixed_id, name: 'Mine now' }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "404s on another seller's method" do
      rivals = create(:delivery_method, store: store, seller: create(:seller, store: store))

      patch :update, params: { id: rivals.prefixed_id, name: 'Mine now' }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    # The origin group is derived from the profile and zone, and the model
    # derives it on create only — so narrowing an existing method to a zone
    # has to re-derive it, or the row keeps a group the new zone contradicts.
    it 'narrows the method to a zone' do
      zone = create(:delivery_zone, store: store, delivery_profile: own_method.delivery_profile)

      patch :update, params: { id: own_method.prefixed_id, delivery_zone_id: zone.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(own_method.reload.delivery_zone).to eq(zone)
      expect(own_method.delivery_origin_group).to eq(zone.delivery_origin_group)
    end

    it 'clears the zone so the method serves everywhere its profile reaches' do
      zone = create(:delivery_zone, store: store, delivery_profile: own_method.delivery_profile)
      own_method.update!(delivery_zone: zone, delivery_origin_group: zone.delivery_origin_group)

      patch :update, params: { id: own_method.prefixed_id, delivery_zone_id: nil }, as: :json

      expect(response).to have_http_status(:ok)
      expect(own_method.reload.delivery_zone).to be_nil
      expect(own_method.delivery_origin_group).to be_present
    end

    it "404s on another store's zone" do
      elsewhere = create(:delivery_zone, store: create(:store))

      patch :update, params: { id: own_method.prefixed_id, delivery_zone_id: elsewhere.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE #destroy' do
    it "retires the seller's own method" do
      own_method = create(:delivery_method, store: store, seller: seller)

      delete :destroy, params: { id: own_method.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::DeliveryMethod.find_by(id: own_method.id)).to be_nil
    end

    it "404s on a marketplace method" do
      shared = create(:delivery_method, store: store, available_to_sellers: true)

      delete :destroy, params: { id: shared.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(shared.reload).to be_present
    end
  end

  describe 'GET #rule_types' do
    it 'offers only the conditions a seller may set' do
      get :rule_types, as: :json

      types = json_response['data'].pluck('type')
      expect(types).to include('item_total_rule', 'weight_rule')
      expect(types).not_to include('channel_rule', 'excluded_products_rule')
    end
  end

  describe 'GET #calculators' do
    it 'lists the ways a seller can price a method' do
      get :calculators, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].pluck('type')).to include('Spree::Calculator::Shipping::FlatRate')
    end
  end
end
