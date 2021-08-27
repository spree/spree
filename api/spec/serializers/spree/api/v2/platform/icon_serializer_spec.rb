require 'spec_helper'

describe Spree::Api::V2::Platform::IconSerializer do
  subject { described_class.new(icon) }

  let(:menu) { create(:menu) }
  let(:menu_item) { create(:menu_item, menu: menu) }
  let(:icon) { create(:icon, viewable: menu_item) }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    expect(subject.serializable_hash).to eq(
      {
        data: {
          id: icon.id.to_s,
          type: :icon,
          attributes: {
            url: Rails.application.routes.url_helpers.polymorphic_url(icon.attachment, only_path: true)
          }
        }
      }
    )
  end

  it { expect(subject.serializable_hash[:data][:id]).to be_kind_of(String) }
  it { expect(subject.serializable_hash[:data][:type]).to be(:icon) }
  it { expect(subject.serializable_hash[:data][:attributes][:url]).to include('thinking-cat.jpg') }
end
