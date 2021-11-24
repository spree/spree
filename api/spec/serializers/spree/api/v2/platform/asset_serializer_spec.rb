require 'spec_helper'

describe Spree::Api::V2::Platform::AssetSerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(resource, params: serializer_params).serializable_hash }

  let(:viewable) { create(:variant) }
  let(:type) { :asset }
  let(:resource) { create(type, viewable: viewable) }

  it do
    expect(subject).to eq(
      data: {
        id: resource.id.to_s,
        attributes: {
          viewable_type: resource.viewable_type,
          attachment_height: resource.attachment_height,
          attachment_file_size: resource.attachment_file_size,
          position: resource.position,
          attachment_content_type: resource.attachment_content_type,
          attachment_file_name: resource.attachment_file_name,
          type: resource.type,
          attachment_updated_at: resource.attachment_updated_at,
          alt: resource.alt,
          created_at: resource.created_at,
          updated_at: resource.updated_at,
          public_metadata: resource.public_metadata,
          private_metadata: resource.private_metadata
        },
        relationships: {
          viewable: {
            data: {
              id: viewable.id.to_s,
              type: :variant
            }
          }
        },
        type: type
      }
    )
  end

  it_behaves_like 'an ActiveJob serializable hash'
end
