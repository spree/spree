require 'swagger_helper'

describe 'Addresses API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Address'
  include_example = 'user,country,state'
  filter_example = 'user_id_eq=1&firstname_cont=Joh'

  let(:id) { create(:address).id }
  let(:records_list) { create_list(:address, 2) }
  let(:country) { create(:country, states_required: true) }
  let(:state) { create(:state, country: country) }
  let(:user) { create(:user) }
  let(:valid_create_param_value) { build(:address, country: country, state: state, user: user).attributes }
  let(:valid_update_param_value) do
    {
      firstname: 'Jack'
    }
  end
  let(:invalid_param_value) do
    {
      firstname: '',
      lastname: ''
    }
  end

  include_examples 'CRUD examples', resource_name, include_example, filter_example
end
