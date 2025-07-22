require 'spec_helper'

describe Spree::Api::V2::Platform::StoreCreditSerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(resource, params: serializer_params).serializable_hash }

  let(:resource) { create(:store_credit) }

  it_behaves_like 'an ActiveJob serializable hash'

  context 'with included relationships' do
    subject do
      described_class.new(resource, include: described_class.relationships_to_serialize.keys).serializable_hash
    end

    it 'serializes the store credit' do
      expect(subject[:data][:id]).to eq(resource.id.to_s)
      expect(subject[:data][:type]).to eq(:store_credit)

      expect(subject[:data][:relationships]).to include(
        created_by: {
          data: {
            id: resource.created_by_id.to_s,
            type: :admin_user
          }
        }
      )

      expect(subject[:included]).to include(hash_including(id: resource.created_by_id.to_s))
    end
  end
end
