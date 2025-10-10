require 'swagger_helper'

describe 'Store Credit Types API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Store Credit Type'
  options = {}

  let(:id) { create(:store_credit_type).id }
  let(:records_list) { create_list(:store_credit_type, 2) }
  let(:valid_create_param_value) { build(:store_credit_type).attributes }
  let(:valid_update_param_value) do
    {
      name: 'default',
      priority: 1
    }
  end
  let(:invalid_param_value) do
    {
      name: ''
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
