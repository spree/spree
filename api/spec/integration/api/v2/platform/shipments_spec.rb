require 'swagger_helper'

describe 'Shipments API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Shipment'
  resource_path = 'shipments'
  options = {
    include_example: 'line_items,variants,product',
    filter_examples: [{ name: 'filter[state_eq]', example: 'complete' }]
  }

  let(:order) { create(:order_ready_to_ship) }
  let(:id) { create(:shipment, order: order).id }
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

  path "/api/v2/platform/#{resource_path}/{id}/ready" do
    patch "Mark Shipment as ready to be shipped" do
      tags resource_name.pluralize
      security [ bearer_auth: [] ]
      description "Marks Shipment as ready to be shipped"
      operationId "ready-shipment"
      consumes 'application/json'
      parameter name: :id, in: :path, type: :string
      json_api_include_parameter(options[:include_example])

      it_behaves_like 'record updated'
      it_behaves_like 'record not found'
      it_behaves_like 'authentication failed'
    end
  end

  path "/api/v2/platform/#{resource_path}/{id}/ship" do
    let(:id) { create(:shipment, order: order, state: :ready).id }

    patch "Mark Shipment as shipped" do
      tags resource_name.pluralize
      security [ bearer_auth: [] ]
      description "Marks Shipment as shipped"
      operationId "ship-shipment"
      consumes 'application/json'
      parameter name: :id, in: :path, type: :string
      json_api_include_parameter(options[:include_example])

      it_behaves_like 'record updated'
      it_behaves_like 'record not found'
      it_behaves_like 'authentication failed'
    end
  end

  path "/api/v2/platform/#{resource_path}/{id}/cancel" do
    patch "Cancels the Shipment" do
      tags resource_name.pluralize
      security [ bearer_auth: [] ]
      description "Cancels the Shipment"
      operationId "cancel-shipment"
      consumes 'application/json'
      parameter name: :id, in: :path, type: :string
      json_api_include_parameter(options[:include_example])

      it_behaves_like 'record updated'
      it_behaves_like 'record not found'
      it_behaves_like 'authentication failed'
    end
  end

  path "/api/v2/platform/#{resource_path}/{id}/resume" do
    let(:id) { create(:shipment, order: order, state: :canceled).id }

    patch "Resumes the Shipment" do
      tags resource_name.pluralize
      security [ bearer_auth: [] ]
      description "Resumes previously canceled Shipment"
      operationId "resume-shipment"
      consumes 'application/json'
      parameter name: :id, in: :path, type: :string
      json_api_include_parameter(options[:include_example])

      it_behaves_like 'record updated'
      it_behaves_like 'record not found'
      it_behaves_like 'authentication failed'
    end
  end

  path "/api/v2/platform/#{resource_path}/{id}/pend" do
    let(:id) { create(:shipment, order: order, state: :ready).id }

    patch "Moves Shipment back to pending state" do
      tags resource_name.pluralize
      security [ bearer_auth: [] ]
      description "Moves Shipment back to pending state"
      operationId "pend-shipment"
      consumes 'application/json'
      parameter name: :id, in: :path, type: :string
      json_api_include_parameter(options[:include_example])

      it_behaves_like 'record updated'
      it_behaves_like 'record not found'
      it_behaves_like 'authentication failed'
    end
  end
end
