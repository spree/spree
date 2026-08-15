require 'spec_helper'

# Pause, Cancel and Resume share one contract: the service records what the
# operator asked for, and the runner records what actually happened. These
# examples cover that split.
RSpec.describe 'maintenance task run control' do
  before do
    stub_const('ControlSpecTask', Class.new(Spree::MaintenanceTask) do
      def self.name = 'ControlSpecTask'
      def collection = Spree::Product.order(:id)
      def process(product) = nil
    end)
    Spree.maintenance_tasks << 'ControlSpecTask'
  end

  after { Spree.maintenance_tasks.delete('ControlSpecTask') }

  let(:run) { create(:maintenance_task_run, task_name: 'ControlSpecTask', status: status) }

  describe Spree::MaintenanceTasks::Pause do
    context 'while the runner is working' do
      let(:status) { 'running' }

      # `pausing` is the request; only the runner may write `paused`, so a
      # worker that dies mid-batch cannot leave the row claiming it stopped.
      it 'asks the runner to stop rather than declaring it stopped' do
        expect(described_class.call(run: run).value).to be_pausing
      end
    end

    context 'before the runner has picked it up' do
      let(:status) { 'enqueued' }

      it 'pauses immediately, since no execution will observe the request' do
        expect(described_class.call(run: run).value).to be_paused
      end
    end

    context 'once the run has finished' do
      let(:status) { 'succeeded' }

      it 'is refused' do
        result = described_class.call(run: run)

        expect(result).to be_failure
        expect(result.error.to_s).to include('cannot be paused')
      end
    end
  end

  describe Spree::MaintenanceTasks::Cancel do
    context 'while the runner is working' do
      let(:status) { 'running' }

      it 'asks the runner to stop for good' do
        expect(described_class.call(run: run).value).to be_cancelling
      end
    end

    context 'while paused' do
      let(:status) { 'paused' }

      it 'cancels outright' do
        result = described_class.call(run: run).value

        expect(result).to be_cancelled
        expect(result.ended_at).to be_present
      end
    end

    context 'when already cancelling' do
      let(:status) { 'cancelling' }

      it 'is refused rather than repeated' do
        expect(described_class.call(run: run)).to be_failure
      end
    end
  end

  describe Spree::MaintenanceTasks::Resume do
    context 'from a pause' do
      let(:status) { 'paused' }

      it 'enqueues a fresh run of the same row' do
        expect { described_class.call(run: run) }.to have_enqueued_job(Spree::MaintenanceTasks::RunJob)

        expect(run.reload).to be_enqueued
      end

      it 'keeps the cursor so the work is not repeated' do
        run.update_columns(cursor: '42', tick_count: 42)

        described_class.call(run: run)

        expect(run.reload.cursor).to eq('42')
        expect(run.tick_count).to eq(42)
      end
    end

    context 'from a failure' do
      let(:status) { 'errored' }

      # The row describes the attempt now under way; the failure that led here
      # is already in the event log.
      it 'clears the recorded error' do
        run.update_columns(error_class: 'ArgumentError', error_message: 'boom')

        described_class.call(run: run)

        expect(run.reload.error_class).to be_nil
        expect(run.error_message).to be_nil
      end
    end

    context 'from a cancelled run' do
      let(:status) { 'cancelled' }

      it 'is refused' do
        result = described_class.call(run: run)

        expect(result).to be_failure
        expect(result.error.to_s).to include('cannot be resumed')
      end
    end

    context 'when another run of the same task started meanwhile' do
      let(:status) { 'paused' }

      it 'is refused' do
        create(:maintenance_task_run, task_name: 'ControlSpecTask', status: 'running')

        result = described_class.call(run: run)

        expect(result).to be_failure
        expect(result.error.to_s).to include('already running')
      end
    end

    context 'when the task was removed from the registry' do
      let(:status) { 'paused' }

      it 'is refused' do
        Spree.maintenance_tasks.delete('ControlSpecTask')

        expect(described_class.call(run: run)).to be_failure
      end
    end
  end
end
