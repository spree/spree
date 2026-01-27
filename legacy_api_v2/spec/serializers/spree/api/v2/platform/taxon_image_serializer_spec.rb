require 'spec_helper'

describe Spree::Api::V2::Platform::TaxonImageSerializer do
  subject { described_class.new(image) }

  let(:image) { create(:taxon_image) }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    expect(subject.serializable_hash).to eq(
      {
        data: {
          id: image.id.to_s,
          type: :taxon_image,
          attributes: {
            alt: image.alt,
            created_at: image.created_at,
            updated_at: image.updated_at,
            transformed_url: image.generate_url(size: ''),
            original_url: image.original_url
          },
        }
      }
    )
  end
end
