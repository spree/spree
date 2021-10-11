require 'swagger_helper'
require 'spec_helper'

describe 'Digitals API', swagger: true do
  include_context 'Platform API v2'
  include ActionDispatch::TestProcess::FixtureFile

  resource_name = 'Digital'
  include_example = nil
  filter_example = nil
  consumes_kind = 'multipart/form-data'
  resource_path = resource_name.parameterize(separator: '_').pluralize

  let(:file_upload) { fixture_file_upload(file_fixture('icon_256x256.jpg'), 'image/jpg') }
  let!(:variant) { create(:variant) }
  let!(:id) { create(:digital).id }
  let!(:records_list) { create_list(:digital, 2) }

  let(:valid_create_param_value) do
    {
      variant_id: variant.id.to_s,
      attachment: file_upload
    }
  end

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

  path "/api/v2/platform/#{resource_path}" do
    include_examples 'GET records list', resource_name, include_example, filter_example
    include_examples 'POST create record', resource_name, include_example, consumes_kind
  end

  path "/api/v2/platform/#{resource_path}/{id}" do
    include_examples 'GET record', resource_name, include_example
    include_examples 'PATCH update record', resource_name, include_example, consumes_kind
    include_examples 'DELETE record', resource_name
  end
end
