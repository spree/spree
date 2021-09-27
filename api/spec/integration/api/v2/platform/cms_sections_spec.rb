require 'swagger_helper'

describe 'CMS Section API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'CMS Section'
  include_example = 'product'
  filter_example = 'name_eq=Hero'

  let!(:store) { Spree::Store.default }
  let!(:product) { create(:product) }
  let!(:cms_page) { create(:cms_feature_page, store: store) }

  let(:id) { create(:cms_hero_image_section, cms_page: cms_page, linked_resource: product).id }
  let(:records_list) { create_list(:cms_hero_image_section, 2, cms_page: cms_page, linked_resource: product) }

  let(:valid_create_param_value) { build(:cms_hero_image_section, cms_page: cms_page, linked_resource: product).attributes }
  let(:valid_update_param_value) do
    {
      name: 'Super Hero'
    }
  end
  let(:invalid_param_value) do
    {
      name: ''
    }
  end

  include_examples 'CRUD examples', resource_name, include_example, filter_example
end
