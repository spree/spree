require 'swagger_helper'

describe 'Taxonomies API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Taxonomy'
  options = {
    include_example: 'taxon',
    filter_examples: [{ name: 'filter[name_eq]', example: 'Category' }]
  }

  let(:id) { create(:taxonomy, store: store).id }
  let(:records_list) { create_list(:taxonomy, 2) }
  let(:valid_create_param_value) { build(:taxonomy).attributes }
  let(:valid_update_param_value) do
    {
      name: 'Category',
      position: 1
    }
  end
  let(:invalid_param_value) do
    {
      name: ''
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
