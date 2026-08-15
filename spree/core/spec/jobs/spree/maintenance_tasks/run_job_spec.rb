require 'spec_helper'
require 'active_job/continuation/test_helper'

RSpec.describe Spree::MaintenanceTasks::RunJob, type: :job do
  let(:store) { @default_store }

  # A task with no dependencies on the rest of the catalog, so the runner's
  # own behavior is what these examples measure.
  before do
    stub_const('SpecMaintenanceTask', Class.new(Spree::MaintenanceTask) do
      cattr_accessor :processed, default: []
      cattr_accessor :raise_on, default: nil
      # Writes a pause/cancel request onto the row after N records, standing
      # in for an operator clicking the button mid-run.
      cattr_accessor :request_after, default: nil
      cattr_accessor :request_status, default: nil

      supports_dry_run
      collection_batch_size 2

      attribute :label, :string
      validates :label, presence: true

      def self.name = 'SpecMaintenanceTask'

      def collection = Spree::Product.order(:id)

      def process(product)
        raise ArgumentError, 'boom' if self.class.raise_on == product.id

        return tally(:would_update) if dry_run?

        self.class.processed << product.id
        tally(:updated)

        if self.class.request_after && self.class.processed.size == self.class.request_after
          run.class.where(id: run.id).update_all(status: self.class.request_status)
        end
      end
    end)

    SpecMaintenanceTask.processed = []
    SpecMaintenanceTask.raise_on = nil
    SpecMaintenanceTask.request_after = nil
    SpecMaintenanceTask.request_status = nil
    Spree.maintenance_tasks << 'SpecMaintenanceTask'
  end

  after { Spree.maintenance_tasks.delete('SpecMaintenanceTask') }

  def start_run(**overrides)
    Spree::MaintenanceTasks::Start.call(
      task_name: 'SpecMaintenanceTask',
      arguments: { 'label' => 'x' },
      initiated_via: 'api',
      **overrides
    ).value
  end

  describe 'a successful run' do
    let!(:products) { create_list(:product, 3, store: store) }

    it 'processes every record and succeeds' do
      run = start_run
      described_class.perform_now(run.id)

      expect(SpecMaintenanceTask.processed).to match_array(products.map(&:id))
      expect(run.reload).to be_succeeded
    end

    it 'records progress and the task tallies' do
      run = start_run
      described_class.perform_now(run.id)

      expect(run.reload.tick_count).to eq(3)
      expect(run.tick_total).to eq(3)
      expect(run.tallies['updated']).to eq(3)
      expect(run.progress).to eq(1.0)
    end

    it 'stamps the cursor so a resume would not repeat work' do
      run = start_run
      described_class.perform_now(run.id)

      expect(run.reload.cursor).to eq(products.max_by(&:id).id.to_s)
    end

    it 'records when it started and ended' do
      run = start_run
      described_class.perform_now(run.id)

      expect(run.reload.started_at).to be_present
      expect(run.ended_at).to be_present
    end
  end

  describe 'dry run' do
    let!(:products) { create_list(:product, 2, store: store) }

    it 'reports what it would do without doing it' do
      run = start_run(dry_run: true)
      described_class.perform_now(run.id)

      expect(SpecMaintenanceTask.processed).to be_empty
      expect(run.reload.tallies['would_update']).to eq(2)
      expect(run).to be_succeeded
    end
  end

  describe 'failure' do
    let!(:products) { create_list(:product, 2, store: store) }

    before { SpecMaintenanceTask.raise_on = Spree::Product.order(:id).first.id }

    it 'records the error on the run instead of raising' do
      run = start_run

      expect { described_class.perform_now(run.id) }.not_to raise_error

      expect(run.reload).to be_errored
      expect(run.error_class).to eq('ArgumentError')
      expect(run.error_message).to eq('boom')
    end

    it 'keeps the failed run resumable' do
      run = start_run
      described_class.perform_now(run.id)

      expect(run.reload).to be_resumable
    end
  end

  describe 'report_on' do
    let!(:products) { create_list(:product, 2, store: store) }

    before do
      SpecMaintenanceTask.report_on(ArgumentError)
      SpecMaintenanceTask.raise_on = Spree::Product.order(:id).first.id
    end

    it 'skips the failing record and finishes the run' do
      run = start_run
      described_class.perform_now(run.id)

      expect(run.reload).to be_succeeded
      expect(run.tallies['reported_errors']).to eq(1)
      expect(SpecMaintenanceTask.processed.size).to eq(1)
    end
  end

  # The control services write the request onto the row and the runner
  # observes it at its next checkpoint. These examples write the same column
  # the services do, from inside the task, so the request lands mid-walk
  # exactly as an operator's would.
  describe 'operator pause' do
    let!(:products) { create_list(:product, 4, store: store) }

    before { SpecMaintenanceTask.request_after = 2 }

    it 'stops at the next checkpoint and keeps its place' do
      run = start_run
      SpecMaintenanceTask.request_status = 'pausing'

      described_class.perform_now(run.id)

      expect(run.reload).to be_paused
      expect(SpecMaintenanceTask.processed.size).to eq(2)
      expect(run.cursor).to eq(Spree::Product.order(:id).limit(2).pluck(:id).last.to_s)
    end

    it 'can be resumed from where it stopped' do
      run = start_run
      SpecMaintenanceTask.request_status = 'pausing'
      described_class.perform_now(run.id)

      SpecMaintenanceTask.request_after = nil
      Spree::MaintenanceTasks::Resume.call(run: run.reload, inline: true)

      expect(SpecMaintenanceTask.processed).to match_array(Spree::Product.order(:id).pluck(:id))
      expect(run.reload).to be_succeeded
    end
  end

  describe 'operator cancel' do
    let!(:products) { create_list(:product, 4, store: store) }

    before { SpecMaintenanceTask.request_after = 2 }

    it 'stops for good' do
      run = start_run
      SpecMaintenanceTask.request_status = 'cancelling'

      described_class.perform_now(run.id)

      expect(run.reload).to be_cancelled
      expect(run).not_to be_resumable
      expect(run.ended_at).to be_present
      expect(SpecMaintenanceTask.processed.size).to eq(2)
    end
  end

  describe 'a task removed from the registry' do
    it 'fails the run rather than retrying forever' do
      run = start_run
      Spree.maintenance_tasks.delete('SpecMaintenanceTask')

      described_class.perform_now(run.id)

      expect(run.reload).to be_errored
      expect(run.error_class).to eq('Spree::MaintenanceTasks::TaskNotRegistered')
    end
  end

  describe 'interruption and resume' do
    include ActiveJob::Continuation::TestHelper

    let!(:products) { create_list(:product, 4, store: store) }

    around do |example|
      original = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      example.run
    ensure
      ActiveJob::Base.queue_adapter = original
    end

    it 'resumes from the cursor instead of restarting the walk' do
      run = start_run
      all_ids = Spree::Product.order(:id).pluck(:id)
      first_batch_cursor = all_ids.first(2).last.to_s

      described_class.perform_later(run.id)

      # Interrupted at the checkpoint after the first batch. The test adapter
      # drains the retry inside the same call, so what this proves is not that
      # the run stopped — it is that the second execution picked up from the
      # cursor rather than from the beginning.
      interrupt_job_during_step(described_class, :process_collection, cursor: first_batch_cursor) do
        perform_enqueued_jobs
      end

      expect(SpecMaintenanceTask.processed).to eq(all_ids)
      expect(run.reload).to be_succeeded
      expect(run.tick_count).to eq(4)
    end

    it 'does not reprocess records that were already applied' do
      run = start_run
      all_ids = Spree::Product.order(:id).pluck(:id)

      described_class.perform_later(run.id)

      interrupt_job_during_step(described_class, :process_collection, cursor: all_ids.first(2).last.to_s) do
        perform_enqueued_jobs
      end

      # Each id appears exactly once: the resumed execution re-read nothing the
      # interrupted one had finished.
      expect(SpecMaintenanceTask.processed).to eq(SpecMaintenanceTask.processed.uniq)
      expect(SpecMaintenanceTask.processed.size).to eq(all_ids.size)
    end
  end
end
