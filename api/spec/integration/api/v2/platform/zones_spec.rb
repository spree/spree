require 'swagger_helper'

describe 'Zones API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Zone'
  options = {
    include_example: 'zone_members',
    filter_examples: [{ name: 'filter[description_eq]', example: 'The zone containing all EU countries' }]
  }

  let(:id) { create(:zone).id }
  let(:records_list) { create_list(:zone, 2) }
  let(:valid_create_param_value) { build(:zone).attributes }
  let(:valid_update_param_value) do
    {
      name: 'EU',
      description: 'The zone containing all EU countries'
    }
  end
  let(:invalid_param_value) do
    {
      name: '',
      description: ''
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
