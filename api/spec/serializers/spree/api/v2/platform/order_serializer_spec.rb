require 'spec_helper'

describe Spree::Api::V2::Platform::OrderSerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(order, params: serializer_params) }

  context 'cart' do
    let(:order) { create(:order) }

    it { expect(subject.serializable_hash).to be_kind_of(Hash) }
  end

  context 'completed order' do
    let(:order) { create(:shipped_order) }

    it { expect(subject.serializable_hash).to be_kind_of(Hash) }
  end
end
