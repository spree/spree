require 'spec_helper'
require 'rake'

describe 'spree:media:migrate_master_images_to_product_media' do
  subject { Rake::Task[task_name] }

  let(:task_name) { 'spree:media:migrate_master_images_to_product_media' }

  # Load the rake file once for the whole describe block. Loading it inside `before`
  # would chain the task body with each example, so a single `invoke` would execute
  # the migration N times after N tests, creating duplicate rows.
  before(:all) do
    Rake::Task.define_task(:environment)
    load File.expand_path(Rails.root + '../../lib/tasks/media.rake')
  end

  before do
    subject.reenable
  end

  context 'when the master variant has no line items' do
    let!(:product) { create(:product) }
    let!(:asset)   { create(:image, viewable: product.master) }

    it 'moves master-pinned assets to the product' do
      expect { subject.invoke }
        .to change { asset.reload.viewable_type }.from('Spree::Variant').to('Spree::Product')

      expect(asset.reload.viewable_id).to eq(product.id)
    end

    it 'updates product media_count' do
      subject.invoke
      expect(product.reload.media_count).to eq(1)
    end

    it 'updates primary_media_id' do
      subject.invoke
      expect(product.reload.primary_media_id).to eq(asset.id)
    end

    it 'is idempotent' do
      subject.invoke
      subject.reenable
      expect { subject.invoke }.not_to change { Spree::Asset.count }
    end
  end

  context 'when the master variant has line items' do
    let!(:product) { create(:product) }
    let!(:asset)   { create(:image, viewable: product.master) }
    let!(:line_item) { create(:line_item, variant: product.master) }

    it 'duplicates the asset onto the product, keeping the master record' do
      expect { subject.invoke }.to change(Spree::Asset, :count).by(1)

      master_asset = Spree::Asset.find_by(viewable_type: 'Spree::Variant', viewable_id: product.master.id)
      product_asset = Spree::Asset.find_by(viewable_type: 'Spree::Product', viewable_id: product.id)
      expect(master_asset).to be_present
      expect(product_asset).to be_present
    end
  end

  context 'when there are no master-pinned images' do
    let!(:product) { create(:product) }

    it 'is a no-op' do
      expect { subject.invoke }.not_to change(Spree::Asset, :count)
    end
  end

  context 'when a non-master variant has pinned images' do
    let!(:product) { create(:product) }
    let!(:variant) { create(:variant, product: product) }
    let!(:asset)   { create(:image, viewable: variant) }

    it 'moves the asset to the product and creates a VariantMedia' do
      expect { subject.invoke }
        .to change { asset.reload.viewable_type }.from('Spree::Variant').to('Spree::Product')
        .and change(Spree::VariantMedia, :count).by(1)

      expect(asset.reload.viewable_id).to eq(product.id)

      link = Spree::VariantMedia.find_by(variant_id: variant.id, media_id: asset.id)
      expect(link).to be_present
    end

    it 'is idempotent — re-running creates no extra links' do
      subject.invoke
      subject.reenable
      expect { subject.invoke }.not_to change(Spree::VariantMedia, :count)
    end
  end

  context 'when a non-master variant with line items has pinned images' do
    let!(:product) { create(:product) }
    let!(:variant) { create(:variant, product: product) }
    let!(:asset)   { create(:image, viewable: variant) }
    let!(:line_item) { create(:line_item, variant: variant) }

    it 'duplicates the asset and links the duplicate to the variant' do
      expect { subject.invoke }
        .to change(Spree::Asset, :count).by(1)
        .and change(Spree::VariantMedia, :count).by(1)

      original = Spree::Asset.find_by(viewable_type: 'Spree::Variant', viewable_id: variant.id)
      duplicate = Spree::Asset.find_by(viewable_type: 'Spree::Product', viewable_id: product.id)
      expect(original).to be_present
      expect(duplicate).to be_present

      link = Spree::VariantMedia.find_by(variant_id: variant.id, media_id: duplicate.id)
      expect(link).to be_present
    end
  end
end
