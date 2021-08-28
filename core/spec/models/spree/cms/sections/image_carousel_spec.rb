require 'spec_helper'

describe Spree::Cms::Sections::ImageCarousel, type: :model do
  let!(:store) { create(:store) }
  let!(:homepage) { create(:cms_homepage, store: store) }

  it 'validates presence of name' do
    expect(described_class.new(name: nil, cms_page: homepage)).not_to be_valid
  end

  it 'validates presence of page' do
    expect(described_class.new(name: 'Got Name')).not_to be_valid
  end

  context 'when a new Image Gallery section is created' do
    let!(:image_carousel_section) { create(:cms_image_carousel_section, cms_page: homepage) }

    it 'sets link_type_one to none' do
      section = Spree::CmsSection.find(image_carousel_section.id)

      expect(section.content[:link_type_one]).to eq('')
    end

    it 'sets link_type_two to none' do
      section = Spree::CmsSection.find(image_carousel_section.id)

      expect(section.content[:link_type_two]).to eq('')
    end

    it 'sets link_type_three to none' do
      section = Spree::CmsSection.find(image_carousel_section.id)

      expect(section.content[:link_type_three]).to eq('')
    end

    it 'sets fit to Container' do
      section = Spree::CmsSection.find(image_carousel_section.id)

      expect(section.fit).to eq('Container')
    end

    it 'sets interval to 5000' do
      section = Spree::CmsSection.find(image_carousel_section.id)

      expect(section.settings[:interval]).to eq(5000)
    end

    it 'sets autoplay setting to active' do
      section = Spree::CmsSection.find(image_carousel_section.id)

      expect(section.active_setting?(:autoplay)).to be_truthy
    end

    it 'sets controls setting to active' do
      section = Spree::CmsSection.find(image_carousel_section.id)

      expect(section.active_setting?(:controls)).to be_falsey
    end

    it 'sets indicators setting to active' do
      section = Spree::CmsSection.find(image_carousel_section.id)

      expect(section.active_setting?(:indicators)).to be_falsey
    end

    it 'sets crossfade setting to active' do
      section = Spree::CmsSection.find(image_carousel_section.id)

      expect(section.active_setting?(:crossfade)).to be_falsey
    end

    it 'sets captions setting to active' do
      section = Spree::CmsSection.find(image_carousel_section.id)

      expect(section.active_setting?(:captions)).to be_falsey
    end

    it 'sets pause setting to active' do
      section = Spree::CmsSection.find(image_carousel_section.id)

      expect(section.active_setting?(:pause)).to be_truthy
    end

    it 'sets wrap setting to active' do
      section = Spree::CmsSection.find(image_carousel_section.id)

      expect(section.active_setting?(:wrap)).to be_truthy
    end

    it '#data_attributes returns settings as data attributes' do
      section = Spree::CmsSection.find(image_carousel_section.id)
      section.wrap = false
      section.pause = false

      expect(section.data_attributes).to eq(
        'data-interval=5000 data-ride=carousel data-wrap=false data-pause=false'
      )
    end
  end

  context 'when set remove fields' do
    let!(:image_carousel_section) { create(:cms_image_carousel_section, cms_page: homepage) }

    it 'remove images' do
      section = Spree::CmsSection.find(image_carousel_section.id)
      expect(section.image_one).to receive(:purge)
      expect(section.image_two).to receive(:purge)
      expect(section.image_three).to receive(:purge)

      section.update(remove_one: true, remove_two: true, remove_three: true)
    end
  end

  if Rails::VERSION::STRING >= '6.1'
    context 'when changing the link types for links one two and three' do
      let!(:image_carousel_section) { create(:cms_image_carousel_section, cms_page: homepage) }

      before do
        section = Spree::CmsSection.find(image_carousel_section.id)

        section.content[:link_type_one] = 'Spree::Product'
        section.content[:link_type_two] = 'Spree::Product'
        section.content[:link_type_three] = 'Spree::Product'

        section.content[:link_one] = 'Shirt 1'
        section.content[:link_two] = 'Shirt 2'
        section.content[:link_three] = 'Shirt 3'

        section.save!
        section.reload
      end

      it 'link_one, link_two and save the initail values' do
        section = Spree::CmsSection.find(image_carousel_section.id)

        expect(section.link_one).to eql 'Shirt 1'
        expect(section.link_two).to eql 'Shirt 2'
        expect(section.link_three).to eql 'Shirt 3'
      end

      it 'link_one, link_two and link_three are reset to nil' do
        section = Spree::CmsSection.find(image_carousel_section.id)

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
