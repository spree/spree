require 'spec_helper'

describe Spree::Asset, type: :model do
  it_behaves_like 'metadata'

  describe '#product' do
    it 'returns the product for the asset' do
      variant = create(:variant)
      asset = create(:asset, viewable: variant)
      expect(asset.product).to eq(variant.product)
    end
  end

  describe 'delegated methods' do
    let(:asset) { create(:image) }
    let(:attachment) { asset.attachment }

    before do
      allow(asset).to receive(:attachment).and_return(attachment)
    end

    it 'delegates :key to attachment' do
      expect(attachment).to receive(:key)
      asset.key
    end

    it 'delegates :attached? to attachment' do
      expect(attachment).to receive(:attached?)
      asset.attached?
    end

    it 'delegates :variant to attachment' do
      expect(attachment).to receive(:variant)
      asset.variant
    end

    it 'delegates :variable? to attachment' do
      expect(attachment).to receive(:variable?)
      asset.variable?
    end

    it 'delegates :blob to attachment' do
      expect(attachment).to receive(:blob)
      asset.blob
    end

    it 'delegates :filename to attachment' do
      expect(attachment).to receive(:filename)
      asset.filename
    end
  end

  describe '.with_session_uploaded_assets_uuid' do
    subject { described_class.with_session_uploaded_assets_uuid(uuid) }

    let!(:assets) { create_list(:asset, 2, session_uploaded_assets_uuid: uuid) }
    let!(:other_assets) { create_list(:asset, 2, session_uploaded_assets_uuid: SecureRandom.uuid) }

    let(:uuid) { SecureRandom.uuid }

    it 'returns assets with the given uuid' do
      expect(subject).to contain_exactly(*assets)
    end
  end
end
