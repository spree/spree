require 'swagger_helper'

describe 'Classifications API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Classification'
  include_example = 'product,taxon'
  filter_example = 'taxon_id_eq=1'

  let(:id) { create(:classification).id }
  let(:records_list) { create_list(:classification, 2) }
  let(:product) { create(:product) }
  let(:taxon) { create(:taxon) }
  let(:valid_create_param_value) { { position: 1, product_id: product.id, taxon_id: taxon.id } }
  let(:valid_update_param_value) do
    {
      position: 1
    }
  end
  let(:invalid_param_value) do
    {
      product_id: nil
    }
  end

  include_examples 'CRUD examples', resource_name, include_example, filter_example

  path '/api/v2/platform/classifications/{id}/reposition' do
    put 'Reposition a Classification' do
      tags resource_name.pluralize
      security [ bearer_auth: [] ]
      operationId 'reposition-classification'
      description 'Reposition a Classification'
      consumes 'application/json'
      parameter name: :id, in: :path, type: :string
      parameter name: :classification, in: :body, schema: { '$ref' => '#/components/schemas/classification_params' }
      json_api_include_parameter(include_example)

      let(:classification) { valid_update_param_value }
      let(:invalid_param_value) do
        {
          position: 'invalid'
        }
      end

      it_behaves_like 'record updated'
      it_behaves_like 'invalid request', :classification
      it_behaves_like 'record not found'
      it_behaves_like 'authentication failed'
    end
  end
end
