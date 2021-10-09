require 'swagger_helper'
require 'spec_helper'

describe 'Digitals API', swagger: true do
  include_context 'Platform API v2'
  include ActionDispatch::TestProcess::FixtureFile

  resource_name = 'Digital'
  include_example = 'variant'
  filter_example = 'name_cont=Birthday'

  let(:file_upload) { fixture_file_upload(file_fixture('icon_256x256.jpg'), 'image/jpg') }
  let!(:variant) { create(:variant) }
  let!(:id) { create(:digital).id }
  let!(:records_list) { create_list(:digital, 2) }

  let(:valid_update_param_value) do
    {
      attachment: file_upload
    }
  end

  let(:invalid_param_value) do
    {
      variant_id: ''
    }
  end

  let(:paramscc) do
    { variant_id: variant.id.to_s, attachment: file_upload }
  end

  resource_path = resource_name.parameterize(separator: '_').pluralize

  path "/api/v2/platform/#{resource_path}" do
    include_examples 'GET records list', resource_name, include_example, filter_example
  end

  path "/api/v2/platform/#{resource_path}/{id}" do
    include_examples 'GET record', resource_name, include_example
    include_examples 'DELETE record', resource_name
  end

  path '/api/v2/platform/digitals' do
    post 'body is required' do
      tags resource_name.pluralize
      consumes 'multipart/form-data'
      security [ bearer_auth: [] ]
      parameter name: :digital, in: :formData, type: :digital, required: true

      let(:digital) do
        {
          variant_id: variant.id.to_s,
          attachment: file_upload
        }
      end

      response '201', 'OK' do
        run_test!
      end
    end
  end
end
