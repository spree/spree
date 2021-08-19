require 'swagger_helper'

describe 'Taxons API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Taxon'
  include_example = 'taxonomy,parent,children'
  filter_example = 'taxonomy_id_eq=1&name_cont=Shirts'

  let(:id) { create(:taxon).id }
  let(:taxonomy) { create(:taxonomy, store: store) }
  let(:records_list) { create_list(:taxon, 2, taxonomy: taxonomy) }
  let(:valid_create_param_value) { build(:taxon, taxonomy: taxonomy).attributes }
  let(:valid_update_param_value) do
    {
      name: 'T-Shirts'
    }
  end
  let(:invalid_param_value) do
    {
      name: '',
    }
  end

  include_examples 'CRUD examples', resource_name, include_example, filter_example
end
