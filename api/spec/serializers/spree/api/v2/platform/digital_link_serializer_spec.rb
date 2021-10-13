require 'spec_helper'

describe Spree::Api::V2::Platform::DigitalLinkSerializer do
  subject { described_class.new(digital_link) }

  let(:digital_link) { create(:digital_link) }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    expect(subject.serializable_hash).to eq(
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

  it { expect(subject.serializable_hash[:data][:id]).to be_kind_of(String) }
  it { expect(subject.serializable_hash[:data][:type]).to be(:digital_link) }
end
