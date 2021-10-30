require 'swagger_helper'

describe 'Payment Methods API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Payment Method'
  options = {
    include_example: 'stores',
    filter_examples: [{ name: 'filter[name]', example: 'Stripe' }],
    custom_update_params: {
      oneOf: [
        { '$ref' => '#/components/schemas/update_payment_method_params' },
        { '$ref' => '#/components/schemas/update_payment_method_params_bogus_gateway' }
      ]
    }
  }

  let!(:store) { Spree::Store.default }
  let!(:store_two) { create(:store) }

  let!(:payment_method) { create(:payment_method, stores: [store]) }
  let!(:payment_method_two) { create(:payment_method, stores: [store]) }
  let!(:payment_method_three) { create(:payment_method, stores: [store]) }

  let(:id) { create(:credit_card_payment_method, stores: [store]).id }
  let(:records_list) { create_list(:credit_card_payment_method, 2, stores: [store]) }

  let(:valid_create_param_value) do
    {
      payment_method: {
        name: 'API Bogus',
        type: 'Spree::Gateway::Bogus',
        display_on: 'both',
        store_ids: [store.id.to_s, store_two.id.to_s]
      }
    }
  end

  let(:valid_update_param_value) do
    {
      payment_method: {
        preferred_test_mode: false,
        preferred_dummy_key: 'UPDATED-DUMMY-KEY-123',
        preferred_server: 'production'
      }
    }
  end

  let(:invalid_param_value) do
    {
      payment_method: {
        name: ''
      }
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
