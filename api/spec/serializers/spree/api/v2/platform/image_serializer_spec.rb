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
            viewable_type: 'Spree::Variant',
            attachment_height: image.attachment_height,
            attachment_file_size: image.attachment_file_size,
            position: image.position,
            attachment_content_type: image.attachment_content_type,
            attachment_file_name: image.attachment_file_name,
            type: image.type,
            attachment_updated_at: image.attachment_updated_at,
            alt: image.alt,
            created_at: image.created_at,
            updated_at: image.updated_at
          },
        }
      }
    )
  end
end
