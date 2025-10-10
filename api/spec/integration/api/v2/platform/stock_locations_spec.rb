require 'swagger_helper'

describe 'Stock Locations API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Stock Location'
  options = {
    include_example: 'country',
    filter_examples: []
  }

  let(:id) { create(:stock_location).id }
  let(:records_list) { create_list(:stock_location, 2) }
  let(:valid_create_param_value) { build(:stock_location).attributes }
  let(:valid_update_param_value) do
    {
      name: 'Warehouse 3',
      default: true,
      address1: 'South Street 8/2',
      city: 'Los Angeles',
      zipcode: '11223',
      active: true
    }
  end
  let(:invalid_param_value) do
    {
      name: ''
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
