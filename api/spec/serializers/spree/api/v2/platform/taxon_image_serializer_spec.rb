require 'spec_helper'

describe Spree::Api::V2::Platform::TaxonImageSerializer do
  subject { described_class.new(taxon_image) }

  let(:taxon_image) { create(:taxon_image) }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    expect(subject.serializable_hash).to eq(
      {
        data: {
          id: taxon_image.id.to_s,
          type: :taxon_image,
          attributes: {
            viewable_type: taxon_image.viewable_type,
            attachment_height: taxon_image.attachment_height,
            attachment_file_size: taxon_image.attachment_file_size,
            position: taxon_image.position,
            attachment_content_type: taxon_image.attachment_content_type,
            attachment_file_name: taxon_image.attachment_file_name,
            type: taxon_image.type,
            attachment_updated_at: taxon_image.attachment_updated_at,
            alt: taxon_image.alt,
            created_at: taxon_image.created_at,
            updated_at: taxon_image.updated_at
          },
        }
      }
    )
  end
end
