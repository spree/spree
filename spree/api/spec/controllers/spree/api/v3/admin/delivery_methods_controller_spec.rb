require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::DeliveryMethodsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    let!(:delivery_method) { create(:delivery_method, name: 'UPS Ground') }

    it 'lists delivery methods with admin fields' do
      get :index, params: {}, as: :json

      expect(response).to have_http_status(:ok)
      data = json_response['data'].find { |row| row['name'] == 'UPS Ground' }
      expect(data).to be_present
      expect(data['delivery_profile_id']).to be_present
      expect(data['calculator_type']).to be_present
    end
  end

  describe 'GET #calculators' do
    it 'lists registered calculators with preference schemas' do
      get :calculators, params: {}, as: :json

      expect(response).to have_http_status(:ok)
      types = json_response['data'].map { |row| row['type'] }
      expect(types).to include('Spree::Calculator::Shipping::FlatRate')
      flat_rate = json_response['data'].find { |row| row['type'] == 'Spree::Calculator::Shipping::FlatRate' }
      expect(flat_rate['preference_schema']).to be_an(Array)
    end
  end

  describe 'GET #fulfillment_providers' do
    it 'lists registered providers with their class predicates' do
      get :fulfillment_providers, params: {}, as: :json

      expect(response).to have_http_status(:ok)
      pickup = json_response['data'].find { |row| row['type'] == 'Spree::FulfillmentProvider::Pickup' }
      expect(pickup['name']).to eq('Pickup')
      expect(pickup['pickup']).to be true
      expect(pickup['requires_address']).to be false

      manual = json_response['data'].find { |row| row['type'] == 'Spree::FulfillmentProvider::Manual' }
      expect(manual['digital']).to be false
      expect(manual['pickup']).to be false
      expect(manual['requires_address']).to be true
      # Providers without credentials are always available; carrier ones are
      # listed with available: false until their integration is connected.
      expect(manual['available']).to be true
      expect(manual['integration_class']).to be_nil
    end
  end

  describe 'GET #rate_providers' do
    it 'lists the registered providers and the default' do
      get :rate_providers, params: {}, as: :json

      expect(response).to have_http_status(:ok)
      internal = json_response['data'].find { |row| row['type'] == 'Spree::DeliveryRateProvider::Internal' }
      expect(internal['name']).to eq('Internal')
      expect(internal['integration_class']).to be_nil
      expect(internal['service_catalog']).to eq([])
      expect(internal['service_catalog_error']).to be_nil
      expect(internal['integration_type']).to be_nil
      expect(json_response['default']).to eq('Spree::DeliveryRateProvider::Internal')
    end

    # Unconnected providers are listed but flagged, so the dashboard can
    # offer connecting the integration inline; DeliveryMethod still rejects
    # an unavailable provider on save.
    it 'marks providers unavailable to the current store' do
      provider_class = Class.new(Spree::DeliveryRateProvider::Base) do
        def self.integration_class = 'Spree::Integrations::Unconnected'
        def self.available_for_store?(_store) = false
      end
      stub_const('UnavailableRateProvider', provider_class)
      Spree.delivery_rate_providers << provider_class

      get :rate_providers, params: {}, as: :json

      row = json_response['data'].find { |entry| entry['type'] == 'UnavailableRateProvider' }
      expect(row['available']).to be false
      expect(json_response['data'].find { |entry| entry['type'] == 'Spree::DeliveryRateProvider::Internal' }['available']).to be true
    ensure
      Spree.delivery_rate_providers.delete(provider_class)
    end
  end


  describe 'carrier services' do
    let(:delivery_method) { create(:delivery_method, store: store) }

    it 'creates service rows with markup and label from a flat payload' do
      patch :update, params: {
        id: delivery_method.prefixed_id,
        markup_percent: 5,
        services: [
          { carrier: 'UPS', service: 'Ground', label: 'UPS standard' },
          { carrier: 'USPS', service: 'Priority', markup_flat: '2.5' }
        ]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['markup_percent']).to eq('5.0')
      services = json_response['services']
      expect(services.size).to eq(2)
      ups = services.find { |row| row['carrier'] == 'UPS' }
      expect(ups['label']).to eq('UPS standard')
      expect(ups['id']).to start_with('dms_')
    end

    it 'reconciles rows: keeps by id, drops the omitted' do
      delivery_method.services = [
        { carrier: 'UPS', service: 'Ground' },
        { carrier: 'USPS', service: 'Priority' }
      ]
      kept = delivery_method.services.find_by(carrier: 'UPS')

      patch :update, params: {
        id: delivery_method.prefixed_id,
        services: [{ id: kept.prefixed_id, carrier: 'UPS', service: 'Ground', label: 'Renamed' }]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(delivery_method.services.reload.map(&:carrier)).to eq(['UPS'])
      expect(kept.reload.label).to eq('Renamed')
    end
  end

  describe 'POST #create' do
    let!(:zone) { create(:delivery_zone) }

    it 'rejects a cross-store delivery profile with 404' do
      other_store_profile = create(:delivery_profile, store: create(:store))

      post :create, params: { name: 'Sneaky', delivery_profile_id: other_store_profile.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'persists the chosen fulfillment provider' do
      post :create, params: {
        name: 'Store pickup',
        fulfillment_provider: 'Spree::FulfillmentProvider::Pickup'
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['fulfillment_provider']).to eq('Spree::FulfillmentProvider::Pickup')
    end

    it 'creates a delivery method with calculator and zone' do
      post :create, params: {
        name: 'Express',
        storefront_visible: true,
        calculator_type: 'Spree::Calculator::Shipping::FlatRate',
        calculator_preferences: { amount: 12.5 },
        delivery_zone_id: zone.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('Express')
      expect(json_response['calculator_type']).to eq('Spree::Calculator::Shipping::FlatRate')
      expect(json_response['delivery_zone_id']).to eq(zone.prefixed_id)
      expect(json_response['delivery_profile_id']).to be_present

      delivery_method = Spree::DeliveryMethod.find_by_prefix_id(json_response['id'])
      expect(delivery_method.calculator.preferred_amount).to eq(12.5)
    end

    it 'creates a pickup method without a calculator requirement' do
      post :create, params: {
        name: 'Store pickup',
        fulfillment_provider: 'Spree::FulfillmentProvider::Pickup',
        calculator_type: 'Spree::Calculator::Shipping::FlatRate'
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['fulfillment_provider']).to eq('Spree::FulfillmentProvider::Pickup')
    end

    it 'assigns configured pickup locations' do
      location = create(:stock_location, pickup_enabled: true)

      post :create, params: {
        name: 'Counter pickup',
        fulfillment_provider: 'Spree::FulfillmentProvider::Pickup',
        stock_location_ids: [location.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['stock_location_ids']).to eq([location.prefixed_id])
    end

    it 'rejects unknown calculator types' do
      post :create, params: {
        name: 'Sneaky',
        calculator_type: 'Kernel'
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #update' do
    let!(:delivery_method) { create(:delivery_method, name: 'UPS Ground') }

    it 'updates attributes and calculator preferences' do
      patch :update, params: {
        id: delivery_method.prefixed_id,
        name: 'UPS Ground v2',
        calculator_preferences: { amount: 99 }
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(delivery_method.reload.name).to eq('UPS Ground v2')
      expect(delivery_method.calculator.preferred_amount).to eq(99)
    end

    # The dashboard sheet saves basics and conditions together.
    it 'saves nested eligibility rules alongside the method' do
      product = create(:product)

      patch :update, params: {
        id: delivery_method.prefixed_id,
        name: 'Express',
        rules: [
          { type: 'item_total_rule', preferences: { minimum_amount: 25 } },
          { type: 'excluded_products_rule', product_ids: [product.prefixed_id] }
        ]
      }, as: :json

      expect(response).to have_http_status(:ok)
      delivery_method.reload
      expect(delivery_method.name).to eq('Express')
      expect(delivery_method.delivery_method_rules.count).to eq(2)

      excluded = delivery_method.delivery_method_rules.detect do |rule|
        rule.is_a?(Spree::DeliveryMethodRules::ExcludedProductsRule)
      end
      expect(excluded.products).to eq([product])
    end

    it 'clears excluded products when an empty array is sent' do
      product = create(:product)
      rule = Spree::DeliveryMethodRules::ExcludedProductsRule.create!(
        delivery_method: delivery_method, products: [product]
      )

      patch :update, params: {
        id: delivery_method.prefixed_id,
        rules: [{ id: rule.prefixed_id, type: 'excluded_products_rule', product_ids: [] }]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(rule.reload.products).to be_empty
      expect(delivery_method.delivery_method_rules.reload.size).to eq(1)
    end

    # An unreachable product cannot become an exclusion, but it must not fail
    # the whole save either — the merchant would have no way to clear it.
    it 'drops nested rule products from another store' do
      foreign_product = create(:product, store: create(:store))
      own_product = create(:product)

      patch :update, params: {
        id: delivery_method.prefixed_id,
        rules: [{
          type: 'excluded_products_rule',
          product_ids: [foreign_product.prefixed_id, own_product.prefixed_id]
        }]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(delivery_method.delivery_method_rules.sole.products).to eq([own_product])
    end
  end

  describe 'DELETE #destroy' do
    let!(:delivery_method) { create(:delivery_method) }

    it 'soft deletes the delivery method' do
      delete :destroy, params: { id: delivery_method.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::DeliveryMethod.find_by(id: delivery_method.id)).to be_nil
      expect(Spree::DeliveryMethod.with_deleted.find(delivery_method.id)).to be_present
    end
  end
end
