require 'spec_helper'

describe Spree::Api::V2::Platform::UserSerializer do
  subject { described_class.new(user) }

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
            created_at: user.created_at,
            updated_at: user.updated_at
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
end
