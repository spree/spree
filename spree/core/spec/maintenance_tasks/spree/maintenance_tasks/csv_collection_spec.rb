require 'spec_helper'
require 'active_job/continuation/test_helper'

RSpec.describe 'CSV maintenance tasks', type: :job do
  let(:store) { @default_store }

  # Unique per example: the variant factory seeds its own SKUs, so fixed ones
  # collide with whatever the product factory already created.
  let(:first_sku) { "MT-#{SecureRandom.hex(4)}" }
  let(:second_sku) { "MT-#{SecureRandom.hex(4)}" }
  let!(:first_variant) { create(:variant).tap { |v| v.update_column(:sku, first_sku) } }
  let!(:second_variant) { create(:variant).tap { |v| v.update_column(:sku, second_sku) } }

  def amount_for(variant)
    variant.reload.amount_in(store.default_currency)&.to_f
  end

  def csv_blob(content)
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(content),
      filename: 'prices.csv',
      content_type: 'text/csv'
    ).signed_id
  end

  def run_task(content, dry_run: false)
    result = Spree::MaintenanceTasks::Start.call(
      task_name: 'Spree::MaintenanceTasks::UpdateVariantPrices',
      dry_run: dry_run,
      initiated_via: 'dashboard',
      csv_file: csv_blob(content),
      inline: true
    )
    result.success? ? result.value.reload : result
  end

  let(:two_rows) { "sku,price\n#{first_sku},19.99\n#{second_sku},29.99\n" }

  it 'applies every row' do
    run = run_task(two_rows)

    expect(run).to be_succeeded
    expect(amount_for(first_variant)).to eq(19.99)
    expect(amount_for(second_variant)).to eq(29.99)
  end

  it 'counts the rows so the run reports real progress' do
    run = run_task(two_rows)

    expect(run.tick_total).to eq(2)
    expect(run.tick_count).to eq(2)
  end

  it 'keeps the uploaded file as the record of what was applied' do
    run = run_task(two_rows)

    expect(run.csv_file).to be_attached
  end

  describe 'dry run' do
    it 'reports without writing' do
      original = amount_for(first_variant)

      run = run_task(two_rows, dry_run: true)

      expect(amount_for(first_variant)).to eq(original)
      expect(run.tallies.values.sum).to eq(2)
    end
  end

  describe 'rows the catalog no longer matches' do
    # A hand-assembled spreadsheet routinely carries a few stale rows; failing
    # the run on the first would make the task useless for its own use case.
    it 'skips them and finishes' do
      run = run_task("sku,price\n#{first_sku},5.00\nGONE-9,7.00\n")

      expect(run).to be_succeeded
      expect(run.tallies['skipped_unknown_sku']).to eq(1)
      expect(amount_for(first_variant)).to eq(5.00)
    end

    it 'skips blank rows' do
      run = run_task("sku,price\n,\n#{first_sku},5.00\n")

      expect(run.tallies['skipped_blank_row']).to eq(1)
    end
  end

  describe 'a task that needs a file' do
    it 'is refused without one' do
      result = Spree::MaintenanceTasks::Start.call(
        task_name: 'Spree::MaintenanceTasks::UpdateVariantPrices',
        initiated_via: 'dashboard'
      )

      expect(result).to be_failure
      expect(result.error.to_s).to include('needs a CSV file')
      expect(Spree::MaintenanceTaskRun.count).to be_zero
    end
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

    before { stub_const('Spree::MaintenanceTasks::UpdateVariantPrices', described_batch_size_task) }

    let(:described_batch_size_task) do
      Class.new(Spree::MaintenanceTasks::UpdateVariantPrices) do
        collection_batch_size 1
        def self.name = 'Spree::MaintenanceTasks::UpdateVariantPrices'
      end
    end

    # The file is re-read on resume, so what proves the cursor works is that no
    # row is applied twice — not that the second execution reads less.
    it 'resumes from the row it reached' do
      result = Spree::MaintenanceTasks::Start.call(
        task_name: 'Spree::MaintenanceTasks::UpdateVariantPrices',
        initiated_via: 'dashboard',
        csv_file: csv_blob(two_rows)
      )
      run = result.value

      interrupt_job_during_step(Spree::MaintenanceTasks::RunJob, :process_collection, cursor: '1') do
        perform_enqueued_jobs
      end

      # Stopped after the first row, with the row number as the resume point.
      expect(run.reload.tick_count).to eq(1)
      expect(run.cursor).to eq('1')
      expect(amount_for(first_variant)).to eq(19.99)

      perform_enqueued_jobs

      expect(run.reload).to be_succeeded
      expect(run.tick_count).to eq(2)
      expect(amount_for(second_variant)).to eq(29.99)
      # The first row was applied once, not re-applied by the resumed run.
      expect(run.tallies['updated']).to eq(2)
    end
  end
end
