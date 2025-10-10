require 'spec_helper'

describe Spree::Api::V2::Platform::RefundSerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(resource, params: serializer_params).serializable_hash }

  let(:resource) { create(:refund, amount: 5.0, refunder: create(:user)) }

  it_behaves_like 'an ActiveJob serializable hash'

  context 'with included relationships' do
    subject do
      described_class.new(resource, include: described_class.relationships_to_serialize.keys).serializable_hash
    end

    it 'serializes the refund' do
      expect(subject[:data][:id]).to eq(resource.id.to_s)
      expect(subject[:data][:type]).to eq(:refund)

      expect(subject[:data][:relationships]).to include(
        refunder: {
          data: {
            id: resource.refunder_id.to_s,
            type: :admin_user
          }
        }
      )

      expect(subject[:included]).to include(hash_including(id: resource.refunder_id.to_s))
    end
  end
end
