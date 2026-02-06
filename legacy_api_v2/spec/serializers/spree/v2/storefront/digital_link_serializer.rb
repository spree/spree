require 'spec_helper'

describe Spree::V2::Storefront::DigitalLinkSerializer do
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
            token: digital_link.token
          }
        }
      }
    )
  end

  it { expect(subject.serializable_hash[:data][:id]).to be_kind_of(String) }
  it { expect(subject.serializable_hash[:data][:type]).to be(:digital_link) }
end
