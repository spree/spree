require 'spec_helper'

describe Spree::Api::V2::Platform::PromotionActionSerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(resource, params: serializer_params) }

  let(:resource) { Spree::PromotionAction.create(promotion: create(:promotion), type: 'Spree::Promotion::Actions::FreeShipping') }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }
end
