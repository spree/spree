require 'spec_helper'

describe Spree::Api::V2::Platform::RoleSerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(resource, params: serializer_params).serializable_hash }

  let(:type) { :role }
  let(:resource) { create(type) }

  it do
    expect(subject).to eq(
      data: {
        id: resource.id.to_s,
        type: type,
        attributes: {
          name: resource.name,
          created_at: resource.created_at,
          updated_at: resource.updated_at
        }
      }
    )
  end

  it_behaves_like 'an ActiveJob serializable hash'
end
