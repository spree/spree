require 'spec_helper'

describe Spree::Cms::Sections::ImageGallery, type: :model do
  let!(:store) { create(:store) }
  let!(:homepage) { create(:cms_homepage, store: store) }

  it 'validates presence of name' do
    expect(described_class.new(name: nil, cms_page: homepage)).not_to be_valid
  end

  it 'validates presence of page' do
    expect(described_class.new(name: 'Got Name')).not_to be_valid
  end

  context 'when a new Image Gallery section is created' do
    let!(:image_gallery_section) { create(:cms_image_gallery_section, cms_page: homepage) }

    it 'sets layout_style to Default' do
      section = Spree::CmsSection.find(image_gallery_section.id)

      expect(section.settings[:layout_style]).to eq('Default')
    end

    it 'sets link_type_one to Spree::Taxon' do
      section = Spree::CmsSection.find(image_gallery_section.id)

      expect(section.content[:link_type_one]).to eq('Spree::Taxon')
    end

    it 'sets link_type_two to Spree::Taxon' do
      section = Spree::CmsSection.find(image_gallery_section.id)

      expect(section.content[:link_type_two]).to eq('Spree::Taxon')
    end

    it 'sets link_type_three to Spree::Taxon' do
      section = Spree::CmsSection.find(image_gallery_section.id)

      expect(section.content[:link_type_three]).to eq('Spree::Taxon')
    end

    it 'sets fit to Container' do
      section = Spree::CmsSection.find(image_gallery_section.id)

      expect(section.fit).to eq('Container')
    end

    it '#fullscreen? is true' do
      section = Spree::CmsSection.find(image_gallery_section.id)

      expect(section.fullscreen?).to be false
    end

    it '#default_layout? is true' do
      section = Spree::CmsSection.find(image_gallery_section.id)

      expect(section.default_layout?).to be true
    end
  end

  if Rails::VERSION::STRING >= '6.0'
    context 'when changing the link types for links one two and three' do
      let!(:image_gallery_section) { create(:cms_image_gallery_section, cms_page: homepage) }

      before do
        section = Spree::CmsSection.find(image_gallery_section.id)

        section.content[:link_type_one] = 'Spree::Product'
        section.content[:link_type_two] = 'Spree::Product'
        section.content[:link_type_three] = 'Spree::Product'

        section.content[:link_one] = 'Shirt 1'
        section.content[:link_two] = 'Shirt 2'
        section.content[:link_three] = 'Shirt 3'

        section.save!
        section.reload
      end

      it 'link_one, link_two and save the initial values' do
        section = Spree::CmsSection.find(image_gallery_section.id)

        expect(section.link_one).to eql 'Shirt 1'
        expect(section.link_two).to eql 'Shirt 2'
        expect(section.link_three).to eql 'Shirt 3'
      end

      it 'link_one, link_two and link_three are reset to nil' do
        section = Spree::CmsSection.find(image_gallery_section.id)

        section.content[:link_type_one] = 'Spree::Taxon'
        section.content[:link_type_two] = 'Spree::Taxon'
        section.content[:link_type_three] = 'Spree::Taxon'
        section.save!
        section.reload

        expect(section.link_one).to be nil
        expect(section.link_two).to be nil
        expect(section.link_three).to be nil
      end
    end
  end
end
