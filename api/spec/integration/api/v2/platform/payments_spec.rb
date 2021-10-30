require 'swagger_helper'

describe 'Payments API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Payment'
  options = {
    include_example: 'payment_method,order,source',
    filter_examples: [{ name: 'filter[payment_method_id_eq]', example: '1' },
                      { name: 'filter[amount_gteq]', example: '99.90' }]
  }

  let(:id) { create(:payment, payment_method: payment_method, order: order).id }
  let(:order) { create(:order, store: store) }
  let(:payment_method) { create(:credit_card_payment_method, stores: [store]) }
  let(:records_list) { create_list(:payment, 2, order: order, payment_method: payment_method) }
  let(:valid_create_param_value) { build(:payment, payment_method: payment_method, order: order) }
  let(:valid_update_param_value) do
    {
      amount: 100.90
    }
  end
  let(:invalid_param_value) do
    {
      amount: 'string',
    }
  end

  # include_examples 'CRUD examples', resource_name, options

  resource_path = resource_name.parameterize(separator: '_').pluralize

  path "/api/v2/platform/#{resource_path}" do
    include_examples 'GET records list', resource_name, options
    # include_examples 'POST create record', resource_name, options
  end

  path "/api/v2/platform/#{resource_path}/{id}" do
    include_examples 'GET record', resource_name, options
    # include_examples 'PATCH update record', resource_name, options
    include_examples 'DELETE record', resource_name, options
  end
end
