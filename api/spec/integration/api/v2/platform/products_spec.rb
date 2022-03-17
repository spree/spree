require 'swagger_helper'

describe 'Products API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Product'
  options = {
    include_example: 'variants,option_types,product_properties,taxons,images,default_variant,primary_variant',
    filter_examples: [{ name: 'filter[name_cont]', example: 'Shirts' }]
  }

  let(:shipping_category) { create(:shipping_category) }
  let(:product) { create(:product) }
  let(:id) { create(:product).id }

  let(:records_list) { create_list(:product, 2) }
  let(:valid_create_param_value) do
    build(:product).attributes.merge(price: '5', shipping_category_id: shipping_category.id)
  end
  let(:valid_update_param_value) do
    {
      name: 'T-Shirts',
      price: '5',
      shipping_category: 'category_id'
    }
  end
  let(:invalid_param_value) do
    {
      name: '',
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
