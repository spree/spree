require 'spec_helper'

describe Spree::Api::V2::Platform::ImageSerializer do
  subject { described_class.new(image) }

  let(:variant) { create(:variant) }
  let(:image) { create(:image, viewable: variant) }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    expect(subject.serializable_hash).to eq(
      {
        data: {
          id: image.id.to_s,
          type: :image,
          attributes: {
            styles: image.styles,
            position: image.position,
            alt: image.alt,
            created_at: image.created_at,
            updated_at: image.updated_at,
            transformed_url: image.generate_url(size: ''),
            original_url: image.original_url
          },
          relationships: {
            viewable: {
              data: {
                id: variant.id.to_s,
                type: :variant
              }
            }
          },
        }
      }
    )
  end
end
