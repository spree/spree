require 'swagger_helper'

describe 'Products API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Product'
  options = {
    include_example: 'prices',
    filter_examples: [{ name: 'filter[name_eq]', example: 'Green Toy Boat' }]
  }

  let(:shipping_category) { create(:shipping_category) }
  let(:id)                { create(:product).id }
  let(:records_list)      { create_list(:product, 2) }

  let(:valid_create_param_value) do
    {
      product: {
        name: 'Spinning Top',
        price: 87.43,
        shipping_category_id: shipping_category.id
      }
    }
  end

  let(:valid_update_param_value) do
    {
      product: {
        name: 'Twirling Bottom',
        price: 33.21
      }
    }
  end

  let(:invalid_param_value) do
    {
      product: {
        name: ''
      }
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
