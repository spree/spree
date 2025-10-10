require 'swagger_helper'

describe 'Store Credit Categories API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Store Credit Category'
  options = {
    filter_examples: [{ name: 'filter[name_eq]', example: 'refunded' }]
  }

  let(:id) { create(:store_credit_category).id }
  let(:records_list) { create_list(:store_credit_category, 2) }
  let(:valid_create_param_value) { build(:store_credit_category).attributes }
  let(:valid_update_param_value) do
    {
      name: 'refunded'
    }
  end
  let(:invalid_param_value) do
    {
      name: ''
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
