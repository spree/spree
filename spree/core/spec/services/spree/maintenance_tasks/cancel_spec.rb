require 'spec_helper'

# The service records what the operator asked for, and the runner records
# what actually happened.
RSpec.describe Spree::MaintenanceTasks::Cancel do
  before do
    stub_const('CancelSpecTask', Class.new(Spree::MaintenanceTask) do
      def self.name = 'CancelSpecTask'
      def collection = Spree::Product.order(:id)
      def process(product) = nil
    end)
    Spree.maintenance_tasks << 'CancelSpecTask'
  end

  after { Spree.maintenance_tasks.delete('CancelSpecTask') }

  let(:run) { create(:maintenance_task_run, task_name: 'CancelSpecTask', status: status) }

  context 'while the runner is working' do
    let(:status) { 'running' }

    it 'asks the runner to stop for good' do
      expect(described_class.call(run: run).value).to be_cancelling
    end
  end

  context 'before the runner has picked it up' do
    let(:status) { 'enqueued' }

    it 'cancels outright, since no execution will observe the request' do
      result = described_class.call(run: run).value

      expect(result).to be_cancelled
      expect(result.ended_at).to be_present
    end

    it 'publishes the cancellation, since the runner never will' do
      expect(run).to receive(:publish_event).with('maintenance_task_run.cancelled')

      described_class.call(run: run)
    end
  end

  # The runner can finish the run between the caller loading it and the
  # service writing; a finished run marked `cancelling` would stay active.
  context 'when the run finished after it was loaded' do
    let(:status) { 'running' }

    it 'is refused and leaves the outcome alone' do
      run
      Spree::MaintenanceTaskRun.where(id: run.id).update_all(status: 'succeeded')

      expect(described_class.call(run: run)).to be_failure
      expect(run.reload).to be_succeeded
    end
  end

  # The way out when the worker that should answer the first request is
  # gone: the run would otherwise stay active and block its task.
  context 'when already cancelling' do
    let(:status) { 'cancelling' }

    it 'cancels outright' do
      result = described_class.call(run: run).value

      expect(result).to be_cancelled
      expect(result).not_to be_active
    end
  end

  context 'once the run has finished' do
    let(:status) { 'succeeded' }

    it 'is refused' do
      result = described_class.call(run: run)

      expect(result).to be_failure
      expect(result.error.to_s).to include('cannot be cancelled')
    end
  end
end
