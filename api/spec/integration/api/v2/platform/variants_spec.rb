require 'swagger_helper'

describe 'Variants API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Variant'
  options = {
    include_example: 'product,tax_category,images,digitals',
    filter_examples: [{ name: 'filter[product_id_eq]', example: '1' },
                      { name: 'filter[sku_i_cont]', example: 'SKU123' }]
  }

  let(:id) { create(:variant, product: product).id }
  let(:product) { create(:product, stores: [store], option_types: [option_type]) }
  let(:option_type) { create(:option_type) }
  let(:option_value) { create(:option_value, option_type: option_type) }
  let(:records_list) { create_list(:variant, 2, product: product) }
  let(:valid_create_param_value) { build(:variant, product: product).attributes.merge(option_value_ids: [option_value.id]) }
  let(:valid_update_param_value) do
    {
      sku: 'SKU987',
      barcode: '978-3-16-148410-0'
    }
  end
  let(:invalid_param_value) do
    {
      sku: '',
    }
  end

  # include_examples 'CRUD examples', resource_name, options

  resource_path = resource_name.parameterize(separator: '_').pluralize

  path "/api/v2/platform/#{resource_path}" do
    include_examples 'GET records list', resource_name, options
    # include_examples 'POST create record', resource_name, options
  end

  path "/api/v2/platform/#{resource_path}/{id}" do
    include_examples 'GET record', resource_name, options
    # include_examples 'PATCH update record', resource_name, options
    include_examples 'DELETE record', resource_name, options
  end
end
