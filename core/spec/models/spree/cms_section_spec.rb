require 'spec_helper'

describe Spree::CmsSection, type: :model do
  let!(:store_a) { create(:store) }
  let!(:homepage) { create(:cms_homepage, store: store_a) }

  it 'validates presence of name' do
    expect(described_class.new(name: nil, cms_page: homepage)).not_to be_valid
  end

  it 'validates presence of page' do
    expect(described_class.new(name: 'Got Name')).not_to be_valid
  end

  context 'uploading a png' do
    let!(:store_a) { create(:store) }
    let!(:homepage) { create(:cms_homepage, store: store_a) }

    let(:section) do
      section = build(:cms_hero_image_section, cms_page: homepage)
      section.image_one.attach(io: file, filename: 't-shirt.png')
      section
    end

    let(:file) { File.open(file_fixture('icon_256x256.png')) }

    it 'is valid' do
      expect(section.valid?).to be(true)
    end
  end
end
