require 'swagger_helper'

describe 'Promotions API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Promotions'
  options = {
    include_example: 'promotion_category,promotion_rules,promotion_actions',
    filter_examples: [{ name: 'filter[code_eq]', example: 'BLK-FRI' },
                      { name: 'filter[name_cont]', example: 'New Customer' }]
  }

  let(:promotion_category) { create(:promotion_category) }
  let(:promotion_rule) { create(:promotion_rule) }

  let(:id) { create(:promotion_with_item_adjustment, promotion_category: promotion_category, promotion_rules: [promotion_rule]).id }
  let!(:records_list) { create_list(:promotion_with_item_adjustment, 3, promotion_category: promotion_category, promotion_rules: [promotion_rule]) }
  let(:valid_create_param_value) { build(:promotion_with_item_adjustment, name: 'Black Friday', promotion_category: promotion_category, promotion_rules: [promotion_rule]).attributes }
  let(:valid_update_param_value) do
    {
      name: '10% OFF'
    }
  end
  let(:invalid_param_value) do
    {
      name: ''
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
