require 'swagger_helper'

describe 'Line Items API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Line Item'
  options = {
    include_example: 'order,tax_category,variant.product,digital_links',
    filter_examples: [{ name: 'filter[order_id_eq]', example: '123' }]
  }

  let(:product) { create(:product_in_stock, :without_backorder, stores: [store]) }
  let(:variant) { product.master }
  let(:id) { create(:line_item, order: order, variant: variant).id }
  let(:order) { create(:order, store: store) }
  let(:records_list) { create_list(:line_item, 2, order: order) }
  let(:valid_create_param_value) { build(:line_item, order: order).attributes }
  let(:valid_update_param_value) do
    {
      quantity: 4
    }
  end
  let(:invalid_param_value) do
    {
      order_id: order.id,
      # trying to add too much qty
      quantity: 10_000,
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
