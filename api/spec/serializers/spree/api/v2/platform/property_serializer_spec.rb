require 'spec_helper'

describe Spree::Api::V2::Platform::PropertySerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(resource, params: serializer_params).serializable_hash }

  let(:type) { :property }
  let(:resource) { create(type) }

  it do
    expect(subject).to eq(
      data: {
        id: resource.id.to_s,
        type: type,
        attributes: {
          name: resource.name,
          presentation: resource.presentation,
          created_at: resource.created_at,
          updated_at: resource.updated_at,
          filterable: resource.filterable,
          filter_param: resource.filter_param,
          public_metadata: resource.public_metadata,
          private_metadata: resource.private_metadata
        }
      }
    )
  end

  it_behaves_like 'an ActiveJob serializable hash'
end
