require 'spec_helper'

describe Spree::Api::V2::Platform::ReimbursementCreditSerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(resource, params: serializer_params).serializable_hash }

  let(:type) { :reimbursement_credit }
  let(:resource) { create(type, creditable: create(:store_credit)) }

  it do
    expect(subject).to eq(
      data: {
        id: resource.id.to_s,
        type: type
      }
    )
  end
end
