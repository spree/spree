require 'spec_helper'

describe Spree::Api::V2::Platform::CmsPageSerializer do
  subject { described_class.new(cms_page).serializable_hash }

  let(:cms_page) { create(:cms_feature_page, cms_sections: create_list(:cms_hero_image_section, 2)) }

  it { expect(subject).to be_kind_of(Hash) }

  it do
    expect(subject).to eq(
      {
        data: {
          id: cms_page.id.to_s,
          type: :cms_page,
          attributes: {
            title: cms_page.title,
            meta_title: cms_page.meta_title,
            content: cms_page.content,
            meta_description: cms_page.meta_description,
            visible: cms_page.visible,
            slug: cms_page.slug,
            type: cms_page.type,
            locale: cms_page.locale,
            deleted_at: cms_page.deleted_at,
            created_at: cms_page.created_at,
            updated_at: cms_page.updated_at
          },
          relationships: {
            cms_sections: {
              data: [
                {
                  id: cms_page.cms_sections.first.id.to_s,
                  type: :cms_section
                },
                {
                  id: cms_page.cms_sections.second.id.to_s,
                  type: :cms_section
                }
              ]
            }
          }
        }
      }
    )
  end

  it_behaves_like 'an ActiveJob serializable hash'
end
