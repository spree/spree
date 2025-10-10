require 'swagger_helper'

describe 'Digital Link API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Digital Link'

  let(:digital) { create(:digital) }
  let(:variant) { digital.variant }
  let(:line_item) { create(:line_item, variant: variant) }

  let(:id) { create(:digital_link).id }
  let(:records_list) { create_list(:digital_link, 2) }
  let(:valid_create_param_value) { build(:digital_link, line_item: line_item, digital: digital).attributes }

  let(:valid_update_param_value) do
    {
      access_counter: 0
    }
  end

  let(:invalid_param_value) do
    {
      access_counter: 'string'
    }
  end

  include_examples 'CRUD examples', resource_name

  path '/api/v2/platform/digital_links/{id}/reset' do
    patch "Reset a #{resource_name}" do
      tags resource_name.pluralize
      security [ bearer_auth: [] ]
      operationId 'reset-digital-link'
      description 'Resets a digital link, allowing further downloads.'
      consumes 'application/json'
      parameter name: :id, in: :path, type: :string

      it_behaves_like 'record updated'
      it_behaves_like 'record not found'
      it_behaves_like 'authentication failed'
    end
  end
end
