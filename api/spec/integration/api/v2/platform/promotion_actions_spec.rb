require 'swagger_helper'

describe 'Promotion Actions API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Promotion Action'
  options = {
    skip_invalid_params: true,
    include_example: 'calculator',
    filter_examples: [{ name: 'filter[type_eq]', example: 'Spree::Promotion::Actions::CreateAdjustment' }]
  }

  let(:promotion) { create(:promotion) }

  let(:id) { create(:promotion_action, promotion: promotion).id }
  let(:records_list) { create_list(:promotion_action, 2, promotion: promotion) }
  let(:valid_create_param_value) { build(:promotion_action, promotion: promotion).attributes }
  let(:valid_update_param_value) do
    {
      type: 'Spree::Promotion::Actions::CreateAdjustment'
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
