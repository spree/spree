require 'spec_helper'

describe Spree::Api::V2::Platform::DigitalSerializer do
  subject { described_class.new(digital).serializable_hash }

  let(:digital) { create(:digital) }

  it { expect(subject).to be_kind_of(Hash) }

  it do
    expect(subject).to eq(
      {
        data: {
          id: digital.id.to_s,
          type: :digital,
          attributes: {
            byte_size: digital.attachment.byte_size.to_i,
            content_type: digital.attachment.content_type.to_s,
            filename: digital.attachment.filename.to_s,
            url: Rails.application.routes.url_helpers.polymorphic_url(digital.attachment, only_path: true)
          },
          relationships: {
            variant: {
              data: {
                id: digital.variant.id.to_s,
                type: :variant
              }
            }
          }
        }
      }
    )
  end

  it { expect(subject[:data][:id]).to be_kind_of(String) }
  it { expect(subject[:data][:type]).to be(:digital) }
  it { expect(subject[:data][:attributes][:url]).to include('thinking-cat.jpg') }

  it_behaves_like 'an ActiveJob serializable hash'
end
