require 'swagger_helper'

describe 'Tax Categories API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Tax Category'
  options = {
    include_example: 'tax_rates',
    filter_examples: [{ name: 'filter[name_eq]', example: 'Clothing' },
                      { name: 'filter[is_default_true]', example: '1' },
                      { name: 'filter[tax_code_eq]', example: '1257L' }]
  }

  let(:id) { create(:tax_category).id }
  let(:records_list) { create_list(:tax_category, 2) }
  let(:valid_create_param_value) { build(:tax_category).attributes }
  let(:valid_update_param_value) do
    {
      name: 'Clothing',
      description: "Men's, women's and children's clothing",
      is_default: true,
      tax_code: '1233K'
    }
  end
  let(:invalid_param_value) do
    {
      name: ''
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
