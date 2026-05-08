require 'spec_helper'

describe Spree::Asset, type: :model do
  it_behaves_like 'metadata'
  it_behaves_like 'lifecycle events', event_prefix: 'media'

  describe 'named variants' do
    let(:reflection) { described_class.attachment_reflections['attachment'] }

    it 'defines preprocessed variants based on config' do
      expected_variants = Spree::Config.product_image_variant_sizes.keys
      expect(reflection.named_variants.keys).to match_array(expected_variants)
    end

    Spree::Config.product_image_variant_sizes.each do |name, (width, height)|
      it "defines :#{name} variant with correct options" do
        named_variant = reflection.named_variants[name]
        expect(named_variant).to be_present
        expect(named_variant.transformations[:resize_to_fill]).to eq([width, height])
        expect(named_variant.transformations[:format]).to eq('webp')
        expect(named_variant.instance_variable_get(:@preprocessed)).to eq(true)
      end
    end
  end

  describe '#product' do
    it 'returns the product when viewable is a Variant' do
      variant = create(:variant)
      asset = create(:asset, viewable: variant)
      expect(asset.product).to eq(variant.product)
    end

    it 'returns the product when viewable is a Product' do
      product = create(:product)
      asset = create(:image, viewable: product)
      expect(asset.product).to eq(product)
    end
  end

  describe '#focal_point' do
    let(:asset) { build(:asset, focal_point_x: 0.5, focal_point_y: 0.3) }

    it 'returns hash with x and y' do
      expect(asset.focal_point).to eq({ x: 0.5, y: 0.3 })
    end

    it 'returns nil when coordinates are not set' do
      asset.focal_point_x = nil
      expect(asset.focal_point).to be_nil
    end
  end

  describe '#focal_point=' do
    let(:asset) { build(:asset) }

    it 'sets x and y from hash' do
      asset.focal_point = { x: 0.25, y: 0.75 }
      expect(asset.focal_point_x).to eq(0.25)
      expect(asset.focal_point_y).to eq(0.75)
    end

    it 'clears focal point when set to nil' do
      asset.focal_point = { x: 0.5, y: 0.5 }
      asset.focal_point = nil
      expect(asset.focal_point_x).to be_nil
      expect(asset.focal_point_y).to be_nil
    end
  end

  describe 'media_type' do
    it 'accepts valid media types' do
      %w[image video external_video].each do |type|
        asset = build(:asset, media_type: type)
        asset.valid?
        expect(asset.errors[:media_type]).to be_empty
      end
    end

    it 'rejects invalid media types' do
      asset = build(:asset, media_type: 'audio')
      expect(asset).not_to be_valid
      expect(asset.errors[:media_type]).to be_present
    end

    it 'defaults to image' do
      asset = Spree::Asset.new
      expect(asset.media_type).to eq('image')
    end

    it 'defaults to image for Spree::Image subclass' do
      image = Spree::Image.new
      expect(image.media_type).to eq('image')
    end
  end

  describe 'counter caches with product viewable' do
    let(:product) { create(:product) }

    it 'increments media_count on product when image is created' do
      expect { create(:image, viewable: product) }
        .to change { product.reload.media_count }.by(1)
    end

    it 'decrements media_count on product when image is destroyed' do
      image = create(:image, viewable: product)
      expect { image.destroy }.to change { product.reload.media_count }.by(-1)
    end
  end

  describe 'thumbnail updates with product viewable' do
    let(:product) { create(:product) }

    it 'sets product primary_media_id when image is created' do
      image = create(:image, viewable: product)
      expect(product.reload.primary_media_id).to eq(image.id)
    end

    it 'clears product primary_media_id when image is destroyed' do
      image = create(:image, viewable: product)
      image.destroy
      expect(product.reload.primary_media_id).to be_nil
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

    let!(:assets) { create_list(:asset, 2, session_id: uuid) }
    let!(:other_assets) { create_list(:asset, 2, session_id: SecureRandom.uuid) }

    let(:uuid) { SecureRandom.uuid }

    it 'returns assets with the given uuid' do
      expect(subject).to match_array(assets)
    end
  end

  context 'external URL' do
    before do
      create(:metafield_definition, namespace: 'external', key: 'url', resource_type: 'Spree::Asset')
    end

    describe '.with_external_url' do
      it 'returns assets with the given external URL' do
        asset = create(:asset)
        asset.set_metafield('external.url', 'https://example.com/Example-Image-001.png')
        expect(described_class.with_external_url('https://example.com/Example-Image-001.png')).to include(asset)
      end

      it 'returns no assets if the external URL is blank' do
        expect(described_class.with_external_url(nil)).to be_empty
      end
    end

    describe '#external_url' do
      it 'returns the external URL' do
        asset = create(:asset)
        asset.set_metafield('external.url', 'https://example.com/Example-Image-001.png')
        expect(asset.external_url).to eq('https://example.com/Example-Image-001.png')
      end

      it 'returns nil if the external URL is blank' do
        asset = create(:asset)
        expect(asset.external_url).to be_nil
      end
    end

    describe '#external_url=' do
      it 'sets the external URL' do
        asset = create(:asset)
        asset.external_url = 'https://example.com/Example-Image-001.png'
        expect(asset.external_url).to eq('https://example.com/Example-Image-001.png')
      end
    end
  end
end
