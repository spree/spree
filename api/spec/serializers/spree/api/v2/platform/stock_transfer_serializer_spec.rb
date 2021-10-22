require 'spec_helper'

describe Spree::Api::V2::Platform::StockTransferSerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(resource, params: serializer_params).serializable_hash }

  let(:type) { :stock_transfer }
  let(:resource) { create(type) }

  it do
    expect(subject).to eq(
      data: {
        id: resource.id.to_s,
        type: type,
        attributes: {
          type: resource.type,
          reference: resource.reference,
          created_at: resource.created_at,
          updated_at: resource.updated_at,
          number: resource.number
        }
      }
    )
  end
end
