require 'swagger_helper'

describe 'Digital Link API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Digital Link'
  include_example = nil
  filter_example = nil

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

  include_examples 'CRUD examples', resource_name, include_example, filter_example
end
