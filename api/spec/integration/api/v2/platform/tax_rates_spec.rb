require 'swagger_helper'

describe 'Tax Rates API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Tax Rate'
  options = {
    include_example: 'zone,tax_category',
    filter_examples: [{ name: 'filter[zone_id_eq]', example: '3' },
                      { name: 'filter[amount_gt]', example: '0.05' },
                      { name: 'filter[tax_category_id_eq]', example: '1' }]
  }

  let(:tax_category) { create(:tax_category) }
  let(:id) { create(:tax_rate, tax_category: tax_category).id }
  let(:records_list) { create_list(:tax_rate, 2, tax_category: tax_category) }
  let(:calculator_attributes) { build(:calculator).attributes }
  let(:valid_create_param_value) do
    build(:tax_rate, tax_category: tax_category).attributes.merge('calculator_attributes' => calculator_attributes)
  end
  let(:valid_update_param_value) do
    {
      amount: 25.9,
      zone_id: create(:zone).id,
      tax_category_id: tax_category.id,
      included_in_price: true,
      show_rate_in_label: true
    }
  end
  let(:invalid_param_value) do
    {
      amount: ''
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
