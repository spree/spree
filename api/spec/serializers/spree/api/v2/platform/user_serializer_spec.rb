require 'spec_helper'

describe Spree::Api::V2::Platform::UserSerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(user, params: serializer_params) }

  let(:user) { create(:user_with_addresses) }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    expect(subject.serializable_hash).to eq(
      {
        data: {
          id: user.id.to_s,
          type: :user,
          attributes: {
            email: user.email,
            first_name: user.first_name,
            last_name: user.last_name,
            average_order_value: [],
            lifetime_value: [],
            store_credits: [],
            created_at: user.created_at,
            updated_at: user.updated_at,
            public_metadata: {},
            private_metadata: {}
          },
          relationships: {
            bill_address: {
              data: {
                id: user.bill_address.id.to_s,
                type: :address
              }
            },
            ship_address: {
              data: {
                id: user.ship_address.id.to_s,
                type: :address
              }
            }
          }
        }
      }
    )
  end

  context 'when user has orders' do
    before do
      create(:completed_order_with_totals, user: user, currency: 'USD')
      create(:completed_order_with_totals, user: user, currency: 'EUR')
      create(:store_credit, amount: '100', store: store, user: user, currency: 'USD')
      create(:store_credit, amount: '90', store: store, user: user, currency: 'EUR')
    end

    it do
      expect(subject.serializable_hash[:data][:attributes]).to eq({
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        average_order_value: [{ amount: '110.00', currency: 'USD' }, { amount: '110.00', currency: 'EUR' }],
        lifetime_value: [{ amount: '110.00', currency: 'USD' }, { amount: '110.00', currency: 'EUR' }],
        store_credits: [{ amount: '100.00', currency: 'USD' }, { amount: '90.00', currency: 'EUR' }],
        created_at: user.created_at,
        updated_at: user.updated_at,
        public_metadata: {},
        private_metadata: {}
      })
    end
  end
end
