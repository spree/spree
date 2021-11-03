require 'swagger_helper'

describe 'CMS Pages API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'CMS Page'
  options = {
    include_example: 'cms_sections',
    filter_examples: [{ name: 'filter[type_eq]', example: 'Spree::Cms::Pages::FeaturePage' },
                      { name: 'filter[locale_eq]', example: 'en' },
                      { name: 'filter[title_cont]', example: 'About Us' }],
    custom_create_params: {
      oneOf: [
        { '$ref' => '#/components/schemas/create_standard_cms_page_params' },
        { '$ref' => '#/components/schemas/create_homepage_cms_page_params' },
        { '$ref' => '#/components/schemas/create_feature_cms_page_params' }
      ]
    },
    custom_update_params: {
      oneOf: [
        { '$ref' => '#/components/schemas/update_standard_cms_page_params' },
        { '$ref' => '#/components/schemas/update_homepage_cms_page_params' },
        { '$ref' => '#/components/schemas/update_feature_cms_page_params' }
      ]
    }
  }

  let(:store) { Spree::Store.default }

  let(:id) { create(:cms_standard_page, store: store).id }
  let(:records_list) { create_list(:cms_standard_page, 2, store: store) }
  let(:valid_create_param_value) { build(:cms_standard_page).attributes }
  let(:valid_update_param_value) do
    {
      title: 'My Super Page'
    }
  end
  let(:invalid_param_value) do
    {
      title: ''
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
