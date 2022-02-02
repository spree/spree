require 'spec_helper'

describe Spree::V2::Storefront::CmsSectionSerializer do
  subject { described_class.new(cms_section) }

  let(:cms_section) { create(:cms_section) }

  shared_examples 'returns proper hash' do
    it { expect(subject.serializable_hash).to be_kind_of(Hash) }

    it do
      expect(subject.serializable_hash).to eq(
        {
          data: {
            id: cms_section.id.to_s,
            type: :cms_section,
            attributes: {
              name: cms_section.name,
              content: cms_section.content,
              settings: cms_section.settings,
              link: cms_section.link,
              fit: cms_section.fit,
              type: cms_section.type,
              position: cms_section.position,
              img_one_sm: cms_section.img_one_sm,
              img_one_md: cms_section.img_one_md,
              img_one_lg: cms_section.img_one_lg,
              img_one_xl: cms_section.img_one_xl,
              img_two_sm: cms_section.img_two_sm,
              img_two_md: cms_section.img_two_md,
              img_two_lg: cms_section.img_two_lg,
              img_two_xl: cms_section.img_two_xl,
              img_three_sm: cms_section.img_three_sm,
              img_three_md: cms_section.img_three_md,
              img_three_lg: cms_section.img_three_lg,
              img_three_xl: cms_section.img_three_xl,
              is_fullscreen: false
              },
            relationships: {
              linked_resource: {
                data: cms_section.linked_resource
              }
            }
          }
        }
      )
    end
  end

  context 'cms_hero_image_section' do
     let!(:store) { create(:store) }
     let!(:homepage) { create(:cms_homepage, store: store) }
     let!(:cms_section) do
       section = create(:cms_hero_image_section, cms_page: homepage)
       section.build_image_one
       section.image_one.attachment.attach(io: file, filename: 't-shirt.png')
       section
     end
     let(:file) { File.open(file_fixture('icon_256x256.jpg')) }

     it_behaves_like 'returns proper hash'
   end

  context 'cms_featured_article_section' do
    let(:homepage) { create(:cms_homepage) }
    let(:cms_section) { create(:cms_featured_article_section, name: 'Test', linked_resource_type: 'Spree::Taxon', cms_page: homepage) }

    it_behaves_like 'returns proper hash'
  end

  context 'cms_side_by_side_images_section' do
    let!(:store) { create(:store) }
    let!(:homepage) { create(:cms_homepage, store: store) }
    let!(:cms_section) do
      section = create(:cms_side_by_side_images_section, cms_page: homepage)
      section.build_image_one
      section.image_one.attachment.attach(io: file, filename: 't-shirt.png')
      section
    end
    let(:file) { File.open(file_fixture('icon_256x256.jpg')) }

    it_behaves_like 'returns proper hash'
  end

  context 'cms_image_gallery_section' do
    let!(:store) { create(:store) }
    let!(:homepage) { create(:cms_homepage, store: store) }
    let!(:cms_section) do
      section = create(:cms_image_gallery_section, cms_page: homepage)
      section.build_image_one
      section.image_one.attachment.attach(io: file, filename: 't-shirt.png')
      section
    end
    let(:file) { File.open(file_fixture('icon_256x256.jpg')) }

    it_behaves_like 'returns proper hash'
  end

  context 'cms_product_carousel_section' do
    let(:homepage) { create(:cms_homepage) }
    let(:cms_section) { create(:cms_product_carousel_section, name: 'Test', linked_resource_type: 'Spree::Taxon', cms_page: homepage) }

    it_behaves_like 'returns proper hash'
  end

  context 'cms_rich_text_content_section' do
    let(:homepage) { create(:cms_homepage) }
    let(:cms_section) { create(:cms_rich_text_content_section, cms_page: homepage) }

    it_behaves_like 'returns proper hash'
  end
end
