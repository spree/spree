require 'swagger_helper'

describe 'Adjustments API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Adjustment'
  options = {
    include_example: 'order,adjustable',
    filter_examples: [{ name: 'filter[order_id]', example: '1234' }]
  }

  let(:line_item) { create(:line_item, order: order) }
  let(:id) { create(:adjustment, order: order, adjustable: line_item).id }
  let(:order) { create(:order, store: store) }
  let(:records_list) { create_list(:adjustment, 2, order: order) }
  let(:valid_create_param_value) { build(:adjustment, order: order, adjustable: line_item).attributes }
  let(:valid_update_param_value) do
    {
      amount: 15.0,
      label: 'New label'
    }
  end
  let(:invalid_param_value) do
    {
      label: ''
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
