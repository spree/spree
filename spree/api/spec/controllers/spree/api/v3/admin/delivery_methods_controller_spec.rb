require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::DeliveryMethodsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    let!(:delivery_method) { create(:shipping_method, name: 'UPS Ground') }

    it 'lists delivery methods with admin fields' do
      get :index, params: {}, as: :json

      expect(response).to have_http_status(:ok)
      data = json_response['data'].find { |row| row['name'] == 'UPS Ground' }
      expect(data).to be_present
      expect(data['fulfillment_type']).to eq('shipping')
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

  describe 'POST #create' do
    let!(:zone) { create(:delivery_zone) }

    it 'creates a delivery method with calculator and zones' do
      post :create, params: {
        name: 'Express',
        fulfillment_type: 'shipping',
        storefront_visible: true,
        calculator_type: 'Spree::Calculator::Shipping::FlatRate',
        calculator_preferences: { amount: 12.5 },
        delivery_zone_ids: [zone.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('Express')
      expect(json_response['calculator_type']).to eq('Spree::Calculator::Shipping::FlatRate')
      expect(json_response['delivery_zone_ids']).to eq([zone.prefixed_id])

      delivery_method = Spree::DeliveryMethod.find_by_prefix_id(json_response['id'])
      expect(delivery_method.calculator.preferred_amount).to eq(12.5)
    end

    it 'creates a pickup method without a calculator requirement' do
      post :create, params: {
        name: 'Store pickup',
        fulfillment_type: 'pickup',
        calculator_type: 'Spree::Calculator::Shipping::FlatRate'
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['fulfillment_type']).to eq('pickup')
    end

    it 'rejects unknown calculator types' do
      post :create, params: {
        name: 'Sneaky',
        fulfillment_type: 'shipping',
        calculator_type: 'Kernel'
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #update' do
    let!(:delivery_method) { create(:shipping_method, name: 'UPS Ground') }

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
  end

  describe 'DELETE #destroy' do
    let!(:delivery_method) { create(:shipping_method) }

    it 'soft deletes the delivery method' do
      delete :destroy, params: { id: delivery_method.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::DeliveryMethod.find_by(id: delivery_method.id)).to be_nil
      expect(Spree::DeliveryMethod.with_deleted.find(delivery_method.id)).to be_present
    end
  end
end
