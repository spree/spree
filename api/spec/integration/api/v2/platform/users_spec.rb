require 'swagger_helper'

describe 'Users API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'User'
  options = {
    include_example: 'ship_address,bill_address',
    filter_examples: [{ name: 'filter[user_id_eq]', example: '1' },
                      { name: 'filter[email_cont]', example: 'spree@example.com' }]
  }

  let(:id) { create(:user).id }
  let(:option_type) { create(:user, store: store) }
  let(:records_list) { create_list(:user, 2) }
  let(:valid_create_param_value) { build(:user).attributes }
  let(:valid_update_param_value) do
    {
      email: 'john@example.com'
    }
  end

  let!(:bill_address) { create(:address, user: create(:user)) }
  let(:invalid_param_value) do
    {
      bill_address_id: bill_address.id
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
