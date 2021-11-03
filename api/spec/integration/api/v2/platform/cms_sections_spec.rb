require 'swagger_helper'

describe 'CMS Section API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'CMS Section'
  options = {
    include_example: 'product',
    filter_examples: [{ name: 'filter[name_eq]', example: 'Hero' }],
    custom_create_params: {
      oneOf: [
        { '$ref' => '#/components/schemas/create_hero_image_cms_section_params' },
        { '$ref' => '#/components/schemas/create_product_carousel_cms_section_params' },
        { '$ref' => '#/components/schemas/create_side_by_side_images_cms_section_params' },
        { '$ref' => '#/components/schemas/create_featured_article_cms_section_params' },
        { '$ref' => '#/components/schemas/create_image_gallery_cms_section_params' },
        { '$ref' => '#/components/schemas/create_rich_text_cms_section_params' }
      ]
    },
    custom_update_params: {
      oneOf: [
        { '$ref' => '#/components/schemas/update_hero_image_cms_section_params' },
        { '$ref' => '#/components/schemas/update_product_carousel_cms_section_params' },
        { '$ref' => '#/components/schemas/update_side_by_side_images_cms_section_params' },
        { '$ref' => '#/components/schemas/update_featured_article_cms_section_params' },
        { '$ref' => '#/components/schemas/update_image_gallery_cms_section_params' },
        { '$ref' => '#/components/schemas/update_rich_text_cms_section_params' }
      ]
    }
  }

  let!(:store) { Spree::Store.default }
  let!(:product) { create(:product) }
  let!(:cms_page) { create(:cms_feature_page, store: store) }
  let!(:cms_section) { create(:cms_hero_image_section, cms_page: cms_page) }
  let!(:cms_image_gallery_section) { create(:cms_image_gallery_section, cms_page: cms_page) }
  let!(:cms_featured_article_section) { create(:cms_featured_article_section, cms_page: cms_page) }

  let(:id) { create(:cms_hero_image_section, cms_page: cms_page, linked_resource: product).id }
  let(:records_list) { create_list(:cms_hero_image_section, 2, cms_page: cms_page, linked_resource: product) }

  let(:valid_create_param_value) { build(:cms_hero_image_section, cms_page: cms_page, linked_resource: product).attributes }
  let(:valid_update_param_value) do
    {
      name: 'Super Hero',
      position: 1,
      type: 'Spree::Cms::Sections::HeroImage'
    }
  end

  let(:invalid_param_value) do
    {
      name: ''
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
