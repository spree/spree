require 'spec_helper'

describe Spree::Api::V2::Platform::CreditCardSerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(resource, params: serializer_params) }

  let(:resource) { create(:credit_card) }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }
end
