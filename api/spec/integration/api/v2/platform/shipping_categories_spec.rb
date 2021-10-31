require 'swagger_helper'

describe 'Taxons API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Shipping Category'
  options = {
    filter_examples: [{ name: 'filter[name_i_cont]', example: 'default' }]
  }

  let(:id) { create(:shipping_category).id }
  let(:records_list) { create_list(:shipping_category, 2) }
  let(:valid_create_param_value) { build(:shipping_category).attributes }
  let(:valid_update_param_value) do
    {
      name: 'Default'
    }
  end
  let(:invalid_param_value) do
    {
      name: '',
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
