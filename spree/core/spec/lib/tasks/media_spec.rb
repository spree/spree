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
    load Spree::Core::Engine.root.join('lib', 'tasks', 'media.rake')
  end

  before { subject.reenable }

  context 'with products that need migration' do
    let!(:product_with_master_image)  { create(:product) }
    let!(:product_with_variant_image) { create(:product) }
    let!(:variant)                    { create(:variant, product: product_with_variant_image) }
    let!(:clean_product)              { create(:product) }
    let!(:master_image)  { create(:image, viewable: product_with_master_image.master) }
    let!(:variant_image) { create(:image, viewable: variant) }

    it 'enqueues a job for each product with variant-pinned assets' do
      expect { subject.invoke }.to have_enqueued_job(Spree::Media::MigrateProductAssetsJob)
        .with(product_with_master_image.id)
        .and have_enqueued_job(Spree::Media::MigrateProductAssetsJob)
        .with(product_with_variant_image.id)
    end

    it 'does not enqueue jobs for products without variant-pinned assets' do
      subject.invoke

      enqueued = ActiveJob::Base.queue_adapter.enqueued_jobs.map { |j| j[:args].first }
      expect(enqueued).not_to include(clean_product.id)
    end
  end

  context 'with no variant-pinned assets in the database' do
    let!(:product) { create(:product) }

    it 'enqueues nothing' do
      expect { subject.invoke }.not_to have_enqueued_job(Spree::Media::MigrateProductAssetsJob)
    end
  end

  context 'when run twice' do
    let!(:product) { create(:product) }
    let!(:variant) { create(:variant, product: product) }
    let!(:asset)   { create(:image, viewable: variant) }

    it 'still enqueues for products that have not been processed yet' do
      # First invocation enqueues but doesn't run inline; the asset is still
      # variant-pinned, so the second invocation should enqueue again. The job
      # itself is what enforces idempotency once it runs.
      subject.invoke
      subject.reenable

      expect { subject.invoke }.to have_enqueued_job(Spree::Media::MigrateProductAssetsJob)
        .with(product.id)
    end
  end
end
