require 'swagger_helper'

describe 'Roles API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Role'
  options = {
    filter_examples: [{ name: 'filter[name_eq]', example: 'admin' }]
  }

  let(:id) { create(:role).id }
  let(:records_list) { create_list(:role, 2) }
  let(:valid_create_param_value) { build(:role).attributes }
  let(:valid_update_param_value) do
    {
      name: 'administrator'
    }
  end
  let(:invalid_param_value) do
    {
      name: ''
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
