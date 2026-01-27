require 'spec_helper'

describe Spree::Api::V2::Platform::RefundReasonSerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(resource, params: serializer_params).serializable_hash }

  let(:type) { :refund_reason }
  let(:resource) { create(type) }

  it do
    expect(subject).to eq(
      data: {
        id: resource.id.to_s,
        attributes: {
          name: resource.name,
          active: resource.active,
          mutable: resource.mutable,
          created_at: resource.created_at,
          updated_at: resource.updated_at
        },
        type: type
      }
    )
  end
end
