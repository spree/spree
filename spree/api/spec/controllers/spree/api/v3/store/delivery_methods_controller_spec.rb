require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::DeliveryMethodsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:shipping_method) { create(:shipping_method, name: 'Standard', storefront_visible: true) }
  let!(:pickup_method) do
    create(:shipping_method, name: 'Store pickup', storefront_visible: true).tap do |dm|
      dm.update!(fulfillment_type: 'pickup')
    end
  end
  let!(:hidden_method) { create(:shipping_method, name: 'Internal', storefront_visible: false) }

  before { request.headers['X-Spree-Api-Key'] = api_key.token }

  describe 'GET #index' do
    it 'lists storefront-visible delivery methods' do
      get :index, params: {}, as: :json

      names = json_response['data'].map { |row| row['name'] }
      expect(names).to include('Standard', 'Store pickup')
      expect(names).not_to include('Internal')
    end

    it 'filters by fulfillment_type' do
      get :index, params: { fulfillment_type: 'pickup' }, as: :json

      expect(json_response['data'].map { |row| row['name'] }).to eq(['Store pickup'])
    end
  end

  describe 'GET #pickup_locations' do
    let!(:pickup_location) { create(:stock_location, name: 'Downtown', pickup_enabled: true) }
    let!(:warehouse) { create(:stock_location, name: 'Warehouse', pickup_enabled: false, backorderable_default: false) }

    it 'lists pickup-enabled stock locations' do
      get :pickup_locations, params: { id: pickup_method.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      names = json_response['data'].map { |row| row['name'] }
      expect(names).to include('Downtown')
      expect(names).not_to include('Warehouse')
    end

    context 'when the method has configured pickup locations' do
      let!(:uptown) { create(:stock_location, name: 'Uptown', pickup_enabled: true) }

      it 'lists only the configured locations' do
        pickup_method.pickup_locations << pickup_location

        get :pickup_locations, params: { id: pickup_method.prefixed_id }, as: :json

        expect(json_response['data'].map { |row| row['name'] }).to eq(['Downtown'])
      end
    end

    context 'with a cart the caller cannot access' do
      let(:foreign_cart) { create(:cart_with_line_items, store: store, customer: create(:user)) }

      it 'refuses instead of leaking coverage results' do
        get :pickup_locations, params: { id: pickup_method.prefixed_id, cart_id: foreign_cart.prefixed_id }, as: :json

        expect(response).to have_http_status(:forbidden)
      end

      it 'allows access with the cart token' do
        request.headers['x-spree-token'] = foreign_cart.token

        get :pickup_locations, params: { id: pickup_method.prefixed_id, cart_id: foreign_cart.prefixed_id }, as: :json

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when the location pickup_stock_policy is any' do
      let(:cart) { create(:cart_with_line_items, store: store, customer: user) }

      before { request.headers['x-spree-token'] = cart.token }

      it 'keeps the location even without local stock' do
        pickup_location.update!(pickup_stock_policy: 'any')
        pickup_location.stock_item_or_create(cart.line_items.first.variant).set_count_on_hand(0)

        get :pickup_locations, params: { id: pickup_method.prefixed_id, cart_id: cart.prefixed_id }, as: :json

        expect(json_response['data'].map { |row| row['name'] }).to include('Downtown')
      end
    end

    context 'with a cart' do
      let(:cart) { create(:cart_with_line_items, store: store, customer: user) }
      let(:variant) { cart.line_items.first.variant }

      before { request.headers['x-spree-token'] = cart.token }

      it 'keeps locations that can fulfill the whole cart from local stock' do
        pickup_location.stock_item_or_create(variant).set_count_on_hand(10)

        get :pickup_locations, params: { id: pickup_method.prefixed_id, cart_id: cart.prefixed_id }, as: :json

        expect(json_response['data'].map { |row| row['name'] }).to include('Downtown')
      end

      it 'drops locations without local stock for the cart' do
        pickup_location.stock_item_or_create(variant).set_count_on_hand(0)

        get :pickup_locations, params: { id: pickup_method.prefixed_id, cart_id: cart.prefixed_id }, as: :json

        expect(json_response['data'].map { |row| row['name'] }).not_to include('Downtown')
      end
    end
  end

  describe 'GET #pickup_points' do
    it 'returns 404 when the method has no pickup point provider' do
      get :pickup_points, params: { id: pickup_method.prefixed_id, latitude: 52.2, longitude: 21.0 }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    context 'with a provider configured' do
      before do
        test_provider = Class.new(Spree::PickupPointProvider::Base) do
          def find_nearby(latitude:, longitude:, limit: 20)
            [Spree::PickupPointOption.new(external_id: 'LOCKER1', name: 'Locker One', city: 'Warsaw', provider: 'test')]
          end

          def find_by_external_id(external_id)
            return unless external_id == 'LOCKER1'

            Spree::PickupPointOption.new(external_id: 'LOCKER1', name: 'Locker One', city: 'Warsaw', provider: 'test')
          end
        end
        stub_const('TestPickupPointProvider', test_provider)
        pickup_method.update!(fulfillment_type: 'pickup_point', pickup_point_provider: 'TestPickupPointProvider')
      end

      it 'returns nearby points' do
        get :pickup_points, params: { id: pickup_method.prefixed_id, latitude: 52.2, longitude: 21.0 }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].first['external_id']).to eq('LOCKER1')
        expect(json_response['data'].first['name']).to eq('Locker One')
      end

      it 'requires coordinates' do
        get :pickup_points, params: { id: pickup_method.prefixed_id }, as: :json

        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
