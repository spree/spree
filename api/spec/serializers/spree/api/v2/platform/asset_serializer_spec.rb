require 'spec_helper'

describe Spree::Api::V2::Platform::AssetSerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(asset, params: serializer_params).serializable_hash }

  let(:type) { :asset }
  let(:asset) { create(type) }

  it do
    expect(subject).to eq(
      data: {
        id: asset.id.to_s,
        type: type,
        attributes: {
          viewable_type: asset.viewable_type,
          attachment_height: asset.attachment_height,
          attachment_file_size: asset.attachment_file_size,
          position: asset.position,
          attachment_content_type: asset.attachment_content_type,
          attachment_file_name: asset.attachment_file_name,
          type: asset.type,
          attachment_updated_at: asset.attachment_updated_at,
          alt: asset.alt,
          created_at: asset.created_at,
          updated_at: asset.updated_at
        }
      }
    )
  end
end
