require 'spec_helper'

describe Spree::Api::V2::Platform::OptionTypeSerializer do
  subject { described_class.new(option_type).serializable_hash }

  let(:option_type) { create(:option_type, option_values: create_list(:option_value, 2)) }

  it { expect(subject).to be_kind_of(Hash) }

  it do
    expect(subject).to eq(
      {
        data: {
          id: option_type.id.to_s,
          type: :option_type,
          attributes: {
            name: option_type.name,
            presentation: option_type.presentation,
            position: option_type.position,
            created_at: option_type.created_at,
            updated_at: option_type.updated_at,
            filterable: option_type.filterable,
            public_metadata: {},
            private_metadata: {}
          },
          relationships: {
            option_values: {
              data: [
                {
                  id: option_type.option_values.first.id.to_s,
                  type: :option_value
                },
                {
                  id: option_type.option_values.second.id.to_s,
                  type: :option_value
                }
              ]
            }
          }
        }
      }
    )
  end

  it_behaves_like 'an ActiveJob serializable hash'
end
