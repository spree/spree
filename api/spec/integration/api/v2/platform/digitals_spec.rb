require 'swagger_helper'

describe 'Digitals API', swagger: true do
  include ActionDispatch::TestProcess::FixtureFile

  include_context 'Platform API v2'

  resource_name = 'Digital'
  include_example = 'variant'
  filter_example = 'name_cont=Birthday'

  let(:image) { fixture_file_upload('icon_256x256.jpg') }

  let!(:variant) { create(:variant) }
  let!(:id) { create(:digital).id }
  let!(:records_list) { create_list(:digital, 2) }

  let(:valid_create_param_valuex) do
    create(:digital)
  end

  let(:valid_create_param_value) do
    {
      digital: {
        variant_id: variant.id.to_s,
        attachment: image
      }
    }
  end

  let(:valid_update_param_value) do
    {
      variant_id: variant.id.to_s,
    }
  end

  let(:invalid_param_value) do
    {
      variant_id: ''
    }
  end

  include_examples 'CRUD examples', resource_name, include_example, filter_example
end
