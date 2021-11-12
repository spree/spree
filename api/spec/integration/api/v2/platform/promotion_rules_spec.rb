require 'swagger_helper'

describe 'Promotion Rules API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Promotion Rule'
  options = {
    skip_invalid_params: true,
    include_example: 'user',
    filter_examples: [{ name: 'filter[type_eq]', example: 'Spree::Promotion::Rules::Product' }]
  }

  let(:promotion) { create(:promotion) }

  let(:id) { create(:promotion_rule, promotion: promotion).id }
  let(:records_list) { create_list(:promotion_rule, 2, promotion: promotion) }
  let(:valid_create_param_value) { build(:promotion_rule, promotion: promotion).attributes }
  let(:valid_update_param_value) do
    {
      type: 'Spree::Promotion::Rules::Country'
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
