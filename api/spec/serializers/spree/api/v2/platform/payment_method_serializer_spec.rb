require 'spec_helper'

describe Spree::Api::V2::Platform::PaymentMethodSerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(resource, params: serializer_params) }

  let!(:store) { Spree::Store.default }
  let(:resource) { create(:credit_card_payment_method) }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    expect(subject.serializable_hash).to eq(
      {
        data: {
          id: resource.id.to_s,
          type: :payment_method,
          attributes: {
            name: resource.name,
            description: resource.description,
            auto_capture: nil,
            active: resource.active,
            type: resource.type,
            position: resource.position,
            display_on: resource.display_on,
            deleted_at: resource.deleted_at,
            created_at: resource.created_at,
            updated_at: resource.updated_at,
            preferences: {
              dummy_key: 'PUBLICKEY123',
              server: 'test',
              test_mode: true
            },
            public_metadata: {},
            private_metadata: {}
          },
          relationships: {
            stores: {
              data: [
                {
                  id: store.id.to_s,
                  type: :store
                }
              ]
            }
          }
        }
      }
    )
  end
end
