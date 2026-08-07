require 'spec_helper'
require 'active_job/continuation/test_helper'

RSpec.describe Spree::ProductTypes::ApplyToProductsJob, type: :job do
  let(:store) { @default_store }
  let(:option_type) { create(:option_type, name: 'size') }
  let(:category) { create(:category) }
  let(:product_type) { create(:product_type, option_types: [option_type], categories: [category]) }

  # update_column so the seeding callback doesn't do the job's work for it.
  def product_carrying_the_type
    create(:product).tap { |product| product.update_column(:product_type_id, product_type.id) }
  end

  it 'applies the type to its products' do
    product = product_carrying_the_type

    described_class.perform_now(product_type.id)

    expect(product.reload.option_types).to eq([option_type])
    expect(product.categories).to eq([category])
  end

  it 'settles the category counter cache' do
    product_carrying_the_type

    described_class.perform_now(product_type.id)

    expect(category.reload.products_count).to eq(1)
  end

  it 'does nothing for a type that defines neither option types nor categories' do
    bare_type = create(:product_type)
    product = create(:product)
    product.update_column(:product_type_id, bare_type.id)

    described_class.perform_now(bare_type.id)

    expect(product.reload.option_types).to be_empty
  end

  it 'ignores a deleted product type' do
    expect { described_class.perform_now('nonexistent') }.not_to raise_error
  end

  describe 'interruption and resume' do
    include ActiveJob::Continuation::TestHelper

    around do |example|
      original = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      example.run
    ensure
      ActiveJob::Base.queue_adapter = original
    end

    # One product per batch, so the cursor advances mid-run.
    before { stub_const('Spree::ProductTypes::ApplyToProducts::BATCH_SIZE', 1) }

    it 'resumes from the cursor instead of restarting the backfill' do
      first = product_carrying_the_type
      second = product_carrying_the_type

      described_class.perform_later(product_type.id)

      interrupt_job_during_step(described_class, :apply_to_products, cursor: first.id) do
        perform_enqueued_jobs
      end

      expect(first.reload.option_types).to eq([option_type])
      expect(second.reload.option_types).to be_empty

      perform_enqueued_jobs

      expect(second.reload.option_types).to eq([option_type])
      # Re-running the finished batch adds nothing — the backfill is additive.
      expect(first.reload.option_types).to eq([option_type])
      expect(category.reload.products_count).to eq(2)
    end
  end
end
