require 'spec_helper'

describe Spree::Api::V2::Platform::CountrySerializer do
  subject { described_class.new(country) }

  let(:country) { create(:country, states: create_list(:state, 2)) }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    expect(subject.serializable_hash).to eq(
      {
        data: {
          id: country.id.to_s,
          type: :country,
          attributes: {
            iso_name: country.iso_name,
            iso: country.iso,
            iso3: country.iso3,
            name: country.name,
            numcode: country.numcode,
            states_required: country.states_required,
            created_at: country.created_at,
            updated_at: country.updated_at,
            zipcode_required: country.zipcode_required
          },
          relationships: {
            states: {
              data: [
                {
                  id: country.states.first.id.to_s,
                  type: :state
                },
                {
                  id: country.states.second.id.to_s,
                  type: :state
                }
              ]
            }
          },
        }
      }
    )
  end
end
