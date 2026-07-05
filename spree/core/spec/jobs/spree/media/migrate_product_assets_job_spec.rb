require 'spec_helper'

RSpec.describe Spree::Media::MigrateProductAssetsJob, type: :job do
  subject { described_class.perform_now(product.id) }

  describe '#perform' do
    context 'with master-pinned assets' do
      let!(:product) { create(:product) }
      let!(:asset)   { create(:image, viewable: product.master) }

      it 'moves master-pinned assets to the product' do
        expect { subject }
          .to change { asset.reload.viewable_type }.from('Spree::Variant').to('Spree::Product')

        expect(asset.reload.viewable_id).to eq(product.id)
      end

      it 'does not create VariantMedia rows for master-pinned assets' do
        expect { subject }.not_to change(Spree::VariantMedia, :count)
      end

      it 'updates media_count' do
        subject
        expect(product.reload.media_count).to eq(1)
      end

      it 'updates primary_media_id' do
        subject
        expect(product.reload.primary_media_id).to eq(asset.id)
      end
    end

    context 'with non-master variant-pinned assets' do
      let!(:product) { create(:product) }
      let!(:variant) { create(:variant, product: product) }
      let!(:asset)   { create(:image, viewable: variant) }

      it 'moves the asset to the product and creates a VariantMedia row' do
        expect { subject }
          .to change { asset.reload.viewable_type }.from('Spree::Variant').to('Spree::Product')
          .and change(Spree::VariantMedia, :count).by(1)

        link = Spree::VariantMedia.find_by(variant_id: variant.id, media_id: asset.id)
        expect(link).to be_present
      end

      it 'links each variant-pinned asset to its original variant' do
        other_variant = create(:variant, product: product)
        other_asset   = create(:image, viewable: other_variant)

        subject

        expect(Spree::VariantMedia.where(asset: asset).pluck(:variant_id)).to eq([variant.id])
        expect(Spree::VariantMedia.where(asset: other_asset).pluck(:variant_id)).to eq([other_variant.id])
      end

      it 'refreshes primary_media_id on the linked variant' do
        # update_all + upsert_all skip callbacks; the job must trigger
        # update_thumbnail! explicitly so the variants matrix shows distinct
        # thumbnails after migration.
        subject
        expect(variant.reload.primary_media_id).to eq(asset.id)
      end

      it 'does not duplicate assets even when historical line items exist' do
        create(:line_item, variant: variant)
        expect { subject }.not_to change(Spree::Asset, :count)
      end
    end

    context 'with mixed master + non-master assets' do
      let!(:product)        { create(:product) }
      let!(:variant)        { create(:variant, product: product) }
      let!(:master_asset)   { create(:image, viewable: product.master) }
      let!(:variant_asset)  { create(:image, viewable: variant) }

      it 'moves both, but only creates a join row for the non-master one' do
        expect { subject }
          .to change(Spree::VariantMedia, :count).by(1)

        expect(master_asset.reload.viewable).to eq(product)
        expect(variant_asset.reload.viewable).to eq(product)
        expect(Spree::VariantMedia.find_by(media_id: variant_asset.id, variant_id: variant.id)).to be_present
        expect(Spree::VariantMedia.where(media_id: master_asset.id)).to be_empty
      end
    end

    context 'idempotency' do
      let!(:product) { create(:product) }
      let!(:variant) { create(:variant, product: product) }
      let!(:asset)   { create(:image, viewable: variant) }

      it 're-running the job is a no-op once everything is migrated' do
        described_class.perform_now(product.id)

        expect { described_class.perform_now(product.id) }.not_to change(Spree::VariantMedia, :count)
        expect(Spree::Asset.count).to eq(1)
      end
    end

    context 'when there is nothing to migrate' do
      let!(:product) { create(:product) }

      it 'is a no-op for asset counts' do
        expect { subject }.not_to change(Spree::Asset, :count)
      end

      it 'is a no-op for VariantMedia counts' do
        expect { subject }.not_to change(Spree::VariantMedia, :count)
      end

      it 'does not touch counter caches when nothing changed' do
        expect { subject }.not_to change { product.reload.updated_at }
      end
    end

    context 'when the product has been deleted' do
      let!(:product) { create(:product) }

      before { product.destroy }

      it 'returns without raising' do
        expect { described_class.perform_now(product.id) }.not_to raise_error
      end
    end

    context 'queueing' do
      let(:product) { create(:product) }

      it 'enqueues on the images queue' do
        expect { described_class.perform_later(product.id) }
          .to have_enqueued_job(described_class).on_queue(Spree.queues.images)
      end
    end
  end
end
