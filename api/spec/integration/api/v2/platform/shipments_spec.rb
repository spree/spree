require 'swagger_helper'

describe 'Shipments API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Shipment'
  resource_path = 'shipments'
  options = {
    include_example: 'line_items,variants,product',
    filter_examples: [{ name: 'filter[state_eq]', example: 'complete' }]
  }

  let(:id) { create(:shipment).id }
  let(:records_list) { create_list(:shipment, 2) }
  let(:store) { Spree::Store.default }
  let(:valid_create_param_value) do
    {

    }
  end
  let(:valid_update_param_value) do
    {
    }
  end
  let(:invalid_param_value) do
    {
    }
  end

  path "/api/v2/platform/#{resource_path}" do
    include_examples 'GET records list', resource_name, options
  end

  path "/api/v2/platform/#{resource_path}/{id}" do
    include_examples 'GET record', resource_name, options
    # include_examples 'PATCH update record', resource_name, options
    include_examples 'DELETE record', resource_name
  end

  %w[ready ship cancel resume pend].each do |state|
    path "/api/v2/platform/#{resource_path}/{id}/#{state}" do
      patch "#{state.capitalize} #{resource_name.articleize}" do
        tags resource_name.pluralize
        security [ bearer_auth: [] ]
        description "#{state.capitalize} #{resource_name.articleize}"
        operationId "advance-#{resource_name.parameterize.to_sym}"
        consumes 'application/json'
        parameter name: :id, in: :path, type: :string
        json_api_include_parameter(options[:include_example])

        response '200', 'record updated' do
          run_test!
        end
        it_behaves_like 'record not found'
        it_behaves_like 'authentication failed'
      end
    end
  end
end
