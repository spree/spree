require 'swagger_helper'

describe 'Promotion Categories API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Promotion Category'
  options = {
    include_example: 'promotions',
    filter_examples: [{ name: 'filter[code_eq]', example: 'BLK-FRI' },
                      { name: 'filter[name_eq]', example: '2020 Promotions' }]
  }

  let(:id) { create(:promotion_category, code: 'MJO').id }
  let(:records_list) { create_list(:promotion_category, 2, code: 'POP123') }
  let(:valid_create_param_value) { build(:promotion_category, code: '2021-BFM').attributes }
  let(:valid_update_param_value) do
    {
      name: '2021 Promotions',
      code: '2021-Promos'
    }
  end
  let(:invalid_param_value) do
    {
      name: ''
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
