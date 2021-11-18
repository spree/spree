require 'swagger_helper'

describe 'Stock Items API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Stock Item'
  options = {
    include_example: 'stock_location,variant',
    filter_examples: []
  }

  let(:product) { create(:product, stores: [store]) }
  let(:variant) { product.master }
  let(:variant_2) { create(:variant, product: product) }
  let(:stock_location) { create(:stock_location, propagate_all_variants: false) }
  let(:id) { create(:stock_item, variant: variant, stock_location: stock_location).id }
  let(:records_list) do
    create(:stock_item, stock_location: stock_location, variant: variant)
    create(:stock_item, stock_location: stock_location, variant: variant_2)
  end
  let(:valid_create_param_value) do
    {
      stock_item: {
        variant_id: variant_2.id,
        stock_location_id: stock_location.id,
        cound_on_hand: 100
      }
    }
  end
  let(:valid_update_param_value) do
    {
      count_on_hand: 200
    }
  end
  let(:invalid_param_value) do
    {
      variant_id: nil
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
