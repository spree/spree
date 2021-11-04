require 'spec_helper'

describe Spree::Api::V2::Platform::AddressSerializer do
  subject { described_class.new(address) }

  let(:address) { create(:address, user: create(:user)) }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    expect(subject.serializable_hash).to eq(
      {
        data: {
          id: address.id.to_s,
          type: :address,
          attributes: {
            firstname: address.firstname,
            lastname: address.lastname,
            address1: address.address1,
            address2: address.address2,
            city: address.city,
            zipcode: address.zipcode,
            phone: address.phone,
            state_name: address.state_name,
            alternative_phone: address.alternative_phone,
            company: address.company,
            created_at: address.created_at,
            updated_at: address.updated_at,
            deleted_at: address.deleted_at,
            label: address.label,
            public_metadata: {},
            private_metadata: {}
          },
          relationships: {
            country: {
              data: {
                id: address.country.id.to_s,
                type: :country
              }
            },
            state: {
              data: {
                id: address.state.id.to_s,
                type: :state
              }
            },
            user: {
              data: {
                id: address.user.id.to_s,
                type: :user
              }
            }
          }
        }
      }
    )
  end
end
