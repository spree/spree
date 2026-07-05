require 'spec_helper'

RSpec.describe Spree::VariantMedia, type: :model do
  let(:product) { create(:product) }
  let(:variant) { create(:variant, product: product) }
  let(:asset) { create(:image, viewable: product) }

  describe 'validations' do
    it 'is valid when the asset belongs to the variant product' do
      vm = described_class.new(variant: variant, asset: asset)
      expect(vm).to be_valid
    end

    it 'rejects an asset attached to a different product' do
      other_asset = create(:image, viewable: create(:product))
      vm = described_class.new(variant: variant, asset: other_asset)
      expect(vm).not_to be_valid
      expect(vm.errors[:asset]).to be_present
    end

    it 'enforces uniqueness on (variant_id, media_id)' do
      described_class.create!(variant: variant, asset: asset)
      dup = described_class.new(variant: variant, asset: asset)
      expect(dup).not_to be_valid
    end
  end

  describe 'touch propagation' do
    it 'touches the variant on save' do
      link = described_class.create!(variant: variant, asset: asset)
      # MySQL stores DATETIME at second precision, so touching within the same
      # second as create wouldn't move updated_at. Advance the clock first.
      Timecop.travel(Time.current + 1.second) do
        expect { link.touch }.to change { variant.reload.updated_at }
      end
    end
  end

  describe 'thumbnail propagation' do
    let(:product_for_thumb) { create(:product) }
    let(:variant_for_thumb) { create(:variant, product: product_for_thumb) }
    let(:product_asset) { create(:image, viewable: product_for_thumb) }

    it 'sets the variant primary_media_id when the link is created' do
      expect {
        described_class.create!(variant: variant_for_thumb, asset: product_asset)
      }.to change { variant_for_thumb.reload.primary_media_id }.from(nil).to(product_asset.id)
    end

    it 'clears the variant primary_media_id when the only link is destroyed' do
      link = described_class.create!(variant: variant_for_thumb, asset: product_asset)
      expect { link.destroy }
        .to change { variant_for_thumb.reload.primary_media_id }.from(product_asset.id).to(nil)
    end
  end

  describe 'cleanup' do
    it 'destroys variant_media when the variant is destroyed' do
      described_class.create!(variant: variant, asset: asset)
      expect { variant.destroy }.to change(described_class, :count).by(-1)
    end

    it 'destroys variant_media when the asset is destroyed' do
      described_class.create!(variant: variant, asset: asset)
      expect { asset.destroy }.to change(described_class, :count).by(-1)
    end
  end

end

RSpec.describe Spree::Asset, type: :model do
  describe '#variant_ids=' do
    let(:product) { create(:product) }
    let(:product_asset) { create(:image, viewable: product) }
    let!(:variant_a) { create(:variant, product: product) }
    let!(:variant_b) { create(:variant, product: product) }

    it 'creates links for newly-picked variants' do
      expect {
        product_asset.variant_ids = [variant_a.to_param]
      }.to change(Spree::VariantMedia, :count).by(1)

      expect(product_asset.variant_media.pluck(:variant_id)).to contain_exactly(variant_a.id)
    end

    it 'destroys links for unpicked variants' do
      Spree::VariantMedia.create!(asset: product_asset, variant: variant_a)
      Spree::VariantMedia.create!(asset: product_asset, variant: variant_b)

      expect {
        product_asset.variant_ids = [variant_a.to_param]
      }.to change(Spree::VariantMedia, :count).by(-1)

      expect(product_asset.variant_media.pluck(:variant_id)).to contain_exactly(variant_a.id)
    end

    it 'clears all links when given an empty array' do
      Spree::VariantMedia.create!(asset: product_asset, variant: variant_a)

      expect {
        product_asset.variant_ids = []
      }.to change(Spree::VariantMedia, :count).by(-1)
    end

    it 'rejects variant ids belonging to a different product' do
      other_product = create(:product)
      foreign_variant = create(:variant, product: other_product)

      expect {
        product_asset.variant_ids = [foreign_variant.to_param]
      }.not_to change(Spree::VariantMedia, :count)
    end

    it 'accepts raw integer ids alongside prefixed ones' do
      expect {
        product_asset.variant_ids = [variant_a.id, variant_b.to_param]
      }.to change(Spree::VariantMedia, :count).by(2)
    end

    it 'is a no-op for variant-pinned assets (legacy viewable_type)' do
      legacy_asset = create(:image, viewable: variant_a)

      expect {
        legacy_asset.variant_ids = [variant_b.to_param]
      }.not_to change(Spree::VariantMedia, :count)
    end

    it 'works through ActiveRecord update with mass-assignment' do
      product_asset.update(variant_ids: [variant_a.to_param])
      expect(product_asset.variant_media.pluck(:variant_id)).to contain_exactly(variant_a.id)
    end
  end

end

RSpec.describe Spree::Variant, type: :model do
  describe 'media gallery' do
    let(:product) { create(:product) }
    let(:variant) { create(:variant, product: product) }

    context 'with associated media linked from the product' do
      let!(:product_asset) { create(:image, viewable: product) }
      let!(:link) { Spree::VariantMedia.create!(variant: variant, asset: product_asset) }

      it 'returns associated_media from gallery_media' do
        expect(variant.gallery_media.to_a).to eq([product_asset])
      end

      it 'reports has_associated_media?' do
        expect(variant.reload.has_associated_media?).to be(true)
      end

      it 'reports has_media?' do
        expect(variant.reload.has_media?).to be(true)
      end
    end

    context 'with multiple linked assets' do
      let!(:second_asset) { create(:image, viewable: product) }
      let!(:first_asset)  { create(:image, viewable: product) }

      before do
        # Reverse position order: first_asset is created second but pinned to the
        # top of the gallery via product-level position. Variant gallery should
        # follow the same product-level ordering.
        first_asset.update_columns(position: 1)
        second_asset.update_columns(position: 2)
        Spree::VariantMedia.create!(variant: variant, asset: second_asset)
        Spree::VariantMedia.create!(variant: variant, asset: first_asset)
      end

      it 'inherits gallery order from the product-level asset position' do
        expect(variant.associated_media.to_a).to eq([first_asset, second_asset])
      end
    end

    context 'with only direct images (legacy path)' do
      let!(:direct_image) { create(:image, viewable: variant) }

      it 'returns direct images from gallery_media' do
        expect(variant.gallery_media.to_a).to eq([direct_image])
      end

      it 'reports has_media? via images count' do
        expect(variant.reload.has_media?).to be(true)
      end
    end

    context 'without any media' do
      it 'returns an empty gallery' do
        expect(variant.gallery_media.to_a).to be_empty
      end

      it 'reports no media' do
        expect(variant.has_media?).to be(false)
      end
    end
  end
end
