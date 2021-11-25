require 'spec_helper'

describe Spree::Api::V2::Platform::OptionValueSerializer do
  subject { described_class.new(option_value).serializable_hash }

  let(:option_value) { create(:option_value) }

  it { expect(subject).to be_kind_of(Hash) }

  it do
    expect(subject).to eq(
      {
        data: {
          id: option_value.id.to_s,
          type: :option_value,
          attributes: {
            position: option_value.position,
            name: option_value.name,
            presentation: option_value.presentation,
            created_at: option_value.created_at,
            updated_at: option_value.updated_at,
            public_metadata: {},
            private_metadata: {}
          },
          relationships: {
            option_type: {
              data: {
                id: option_value.option_type.id.to_s,
                type: :option_type
              }
            },
          }
        }
      }
    )
  end

  it_behaves_like 'an ActiveJob serializable hash'
end
