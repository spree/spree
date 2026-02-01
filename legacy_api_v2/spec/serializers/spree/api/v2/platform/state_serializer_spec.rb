require 'spec_helper'

describe Spree::Api::V2::Platform::StateSerializer do
  subject { described_class.new(state) }

  let(:country) { create(:country) }
  let(:state) { create(:state, country: country) }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    expect(subject.serializable_hash).to eq(
      {
        data: {
          id: state.id.to_s,
          type: :state,
          attributes: {
            name: state.name,
            abbr: state.abbr,
            created_at: state.created_at,
            updated_at: state.updated_at
          },
          relationships: {
            country: {
              data: {
                id: country.id.to_s,
                type: :country
              }
            },
          },
        }
      }
    )
  end
end
