require 'swagger_helper'

describe 'Taxons API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Taxon'
  options = {
    include_example: 'taxonomy,parent,children',
    filter_examples: [{ name: 'filter[taxonomy_id_eq]', example: '1' },
                      { name: 'filter[name_cont]', example: 'Shirts' }]
  }

  let(:taxonomy) { create(:taxonomy, store: store) }
  let(:id) { create(:taxon, taxonomy: taxonomy).id }

  let!(:taxon_b) { create(:taxon, name: 'Shorts', taxonomy: taxonomy) }

  let(:records_list) { create_list(:taxon, 2, taxonomy: taxonomy) }
  let(:valid_create_param_value) { build(:taxon, taxonomy: taxonomy).attributes }
  let(:valid_update_param_value) do
    {
      name: 'T-Shirts',
      public_metadata: { 'profitability' => 3 }
    }
  end
  let(:invalid_param_value) do
    {
      name: '',
    }
  end
  let(:valid_update_position_param_value) do
    {
      taxon: {
        new_parent_id: taxon_b.id,
        new_position_idx: 0
      }
    }
  end

  include_examples 'CRUD examples', resource_name, options

  path '/api/v2/platform/taxons/{id}/reposition' do
    patch 'Reposition a Taxon' do
      tags resource_name.pluralize
      security [ bearer_auth: [] ]
      operationId 'reposition-taxon'
      description 'Reposition a Taxon'
      consumes 'application/json'
      parameter name: :id, in: :path, type: :string
      parameter name: :taxon, in: :body, schema: { '$ref' => '#/components/schemas/taxon_reposition' }

      let(:taxon) { valid_update_position_param_value }

      it_behaves_like 'record updated'
      it_behaves_like 'record not found', :taxon
      it_behaves_like 'authentication failed'
    end
  end
end
