require 'swagger_helper'

describe 'Taxonomies API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Taxonomy'
  options = {
    include_example: 'taxons,root',
    filter_examples: [{ name: 'filter[name_eq]', example: 'Categories' }]
  }

  let(:store) { @default_store }
  let(:id) { store.taxonomies.first.id }
  let(:records_list) { create_list(:taxonomy, 2, store: store) }
  let(:valid_create_param_value) do
    {
      name: 'First Taxonomy',
      store: store
    }
  end
  let(:valid_update_param_value) do
    {
      name: 'Updated Taxonomy',
      position: 1,
      public_metadata: { balanced: true }
    }
  end
  let(:invalid_param_value) do
    {
      name: ''
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
