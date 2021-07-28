require 'spec_helper'

describe Spree::V2::Storefront::CmsSectionSerializer do
  let(:expected_hash) do
    {
      data:
        { attributes:
            { content: nil,
              fit: nil,
              img_one_lg: nil,
              img_one_md: nil,
              img_one_sm: nil,
              img_one_xl: nil,
              img_three_lg: nil,
              img_three_md: nil,
              img_three_sm: nil,
              img_three_xl: nil,
              img_two_lg: nil,
              img_two_md: nil,
              img_two_sm: nil,
              img_two_xl: nil,
              is_fullscreen: false,
              link: nil,
              name: cms_section.name,
              position: cms_section.position,
              settings: nil,
              type: nil },
          id: cms_section.id.to_s,
          relationships: { linked_resource: { data: nil } },
          type: :cms_section }
      }
  end
  context 'default csm section' do
    let(:cms_section) { create(:cms_section, name: 'Test Name') }
    before do
      # cms_section.image_one.attach(io: image_file, filename: 'Test Image')
    end

    subject { described_class.new(cms_section) }

    it { expect(subject.serializable_hash).to be_kind_of(Hash) }

    it do
      expect(subject.serializable_hash).to eq(expected_hash)
    end
  end
  context 'feature article csm section' do
    let!(:cms_section) do
      section = build(:cms_hero_image_section)
      section.image_one.attach(io: image_file, filename: 'thinking-cat.jpg')
      section
    end
    # it { binding.pry }

    before do

    end
    let(:image_file) { File.open('spec/fixtures/thinking-cat.jpg') }
    subject { described_class.new(cms_section) }

    it { expect(subject.serializable_hash).to be_kind_of(Hash) }

    it do
      # def cms_section.img_one_lg
        # binding.pry
        # super('100x100')
      # end
      expect(subject.serializable_hash).to eq(expected_hash)
    end
  end
end
