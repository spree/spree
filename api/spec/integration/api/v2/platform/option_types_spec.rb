require 'swagger_helper'

describe 'Option Types API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Option Type'
  options = {
    filter_examples: [{ name: 'filter[option_type_id_eq]', example: '1' },
                      { name: 'filter[name_cont]', example: 'Size' }]
  }

  let(:id) { create(:option_type).id }
  let(:option_type) { create(:option_type) }
  let(:records_list) { create_list(:option_type, 2) }
  let(:valid_create_param_value) { build(:option_type).attributes }
  let(:valid_update_param_value) do
    {
      name: 'Size-X'
    }
  end
  let(:invalid_param_value) do
    {
      name: '',
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
