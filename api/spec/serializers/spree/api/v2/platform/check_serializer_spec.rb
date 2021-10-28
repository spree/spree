require 'spec_helper'

describe Spree::Api::V2::Platform::CheckSerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(resource, params: serializer_params) }

  let(:resource) { create(:check_payment) }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    expect(subject.serializable_hash).to eq(
      {
        data: {
          id: resource.id.to_s,
          type: :payment,
          attributes: {
            amount: resource.amount,
            display_amount: resource.display_amount
          },
          relationships: {
            order: {
              data: {
                id: resource.order.id.to_s,
                type: :order
              }
            },
            payment_method: {
              data: {
                id: resource.payment_method.id.to_s,
                type: :payment_method
              }
            },
          }
        }
      }
    )
  end
end
