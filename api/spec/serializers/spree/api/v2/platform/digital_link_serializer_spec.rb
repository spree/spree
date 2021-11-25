require 'spec_helper'

describe Spree::Api::V2::Platform::DigitalLinkSerializer do
  subject { described_class.new(digital_link).serializable_hash }

  let(:digital_link) { create(:digital_link) }

  it { expect(subject).to be_kind_of(Hash) }

  it do
    expect(subject).to eq(
      {
        data: {
          id: digital_link.id.to_s,
          type: :digital_link,
          attributes: {
            access_counter: 0,
            token: digital_link.token
          },
          relationships: {
            digital: {
              data: {
                id: digital_link.digital.id.to_s,
                type: :digital
              }
            },
            line_item: {
              data: {
                id: digital_link.line_item.id.to_s,
                type: :line_item
              }
            }
          }
        }
      }
    )
  end

  it { expect(subject[:data][:id]).to be_kind_of(String) }
  it { expect(subject[:data][:type]).to be(:digital_link) }

  it_behaves_like 'an ActiveJob serializable hash'
end
