require 'spec_helper'

describe Spree::Cms::Sections::SideBySideImages, type: :model do
  let!(:store) { create(:store) }
  let!(:homepage) { create(:cms_homepage, store: store) }

  it 'validates presence of name' do
    expect(described_class.new(name: nil, cms_page: homepage)).not_to be_valid
  end

  it 'validates presence of page' do
    expect(described_class.new(name: 'Got Name')).not_to be_valid
  end

  context 'when a new Image Gallery section is created' do
    let!(:side_by_side_images_section) { create(:cms_side_by_side_images_section, cms_page: homepage) }

    it 'sets link_type_one to Spree::Taxon' do
      section = Spree::CmsSection.find(side_by_side_images_section.id)

      expect(section.content[:link_type_one]).to eq('Spree::Taxon')
    end

    it 'sets link_type_two to Spree::Taxon' do
      section = Spree::CmsSection.find(side_by_side_images_section.id)

      expect(section.content[:link_type_two]).to eq('Spree::Taxon')
    end

    it 'sets fit to Container' do
      section = Spree::CmsSection.find(side_by_side_images_section.id)

      expect(section.fit).to eq('Container')
    end

    it '#fullscreen? is true' do
      section = Spree::CmsSection.find(side_by_side_images_section.id)

      expect(section.fullscreen?).to be false
    end

    it '#gutters? is true' do
      section = Spree::CmsSection.find(side_by_side_images_section.id)

      expect(section.gutters?).to be true
    end
  end

  if Rails::VERSION::STRING >= '6.0'
    context 'when changing the link types for links one and two' do
      let!(:side_by_side_images_section) { create(:cms_side_by_side_images_section, cms_page: homepage) }

      before do
        section = Spree::CmsSection.find(side_by_side_images_section.id)

        section.content[:link_type_one] = 'Spree::Product'
        section.content[:link_type_two] = 'Spree::Product'

        section.content[:link_one] = 'Shirt 1'
        section.content[:link_two] = 'Shirt 2'

        section.save!
        section.reload
      end

      it 'link_one and link_two save the values correctly' do
        section = Spree::CmsSection.find(side_by_side_images_section.id)

        expect(section.link_one).to eql 'Shirt 1'
        expect(section.link_two).to eql 'Shirt 2'
      end

      it 'link_one and link_two are reset to nil when type is changed' do
        section = Spree::CmsSection.find(side_by_side_images_section.id)

        section.content[:link_type_one] = 'Spree::Taxon'
        section.content[:link_type_two] = 'Spree::Taxon'
        section.save!
        section.reload

        expect(section.link_one).to be nil
        expect(section.link_two).to be nil
      end
    end
  end
end
