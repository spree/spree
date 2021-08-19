require 'swagger_helper'

describe 'Users API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'User'
  include_example = 'ship_address,bill_address'
  filter_example = 'user_id_eq=1&email_cont=spree@example.com'

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

  include_examples 'CRUD examples', resource_name, include_example, filter_example
end
