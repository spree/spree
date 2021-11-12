require 'swagger_helper'

describe 'Store Credits API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Store Credit'
  options = {
    include_example: 'user,created_by,category,credit_type',
    filter_examples: [{ name: 'filter[user_id_eq]', example: '5' },
                      { name: 'filter[created_by_id_eq]', example: '2' },
                      { name: 'filter[amount_gteq]', example: '50.0' },
                      { name: 'filter[currency_eq]', example: 'USD' }]
  }

  let(:user) { create(:user) }
  let(:id) { create(:store_credit, user: user).id }
  let(:records_list) { create_list(:store_credit, 2, user: user) }
  let(:valid_create_param_value) { build(:store_credit, user: user).attributes }
  let(:valid_update_param_value) do
    {
      amount: 500.0,
      memo: 'The user is awarded',
      currency: 'CAD',
      public_metadata: { loyalty_reward: true }
    }
  end
  let(:invalid_param_value) do
    {
      amount: -200,
      store: nil
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
