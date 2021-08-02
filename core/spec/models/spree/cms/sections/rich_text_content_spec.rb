require 'spec_helper'

describe Spree::Cms::Sections::RichTextContent, type: :model do
  let!(:store) { create(:store) }
  let!(:homepage) { create(:cms_homepage, store: store) }

  it 'validates presence of name' do
    expect(described_class.new(name: nil, cms_page: homepage)).not_to be_valid
  end

  it 'validates presence of page' do
    expect(described_class.new(name: 'Got Name')).not_to be_valid
  end

  context 'when a new Rich Text Content section is created' do
    let!(:rich_text_content_section) { create(:cms_rich_text_content_section, cms_page: homepage) }

    it 'sets fit to Screen' do
      section = Spree::CmsSection.find(rich_text_content_section.id)

      expect(section.fit).to eq('Container')
    end
  end
end
