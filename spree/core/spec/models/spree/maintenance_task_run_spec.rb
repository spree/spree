require 'spec_helper'

RSpec.describe Spree::MaintenanceTaskRun do
  it 'starts enqueued' do
    expect(create(:maintenance_task_run)).to be_enqueued
  end

  it 'requires a way to tell where it was fired from' do
    run = build(:maintenance_task_run, initiated_via: 'telepathy')

    expect(run).not_to be_valid
    expect(run.errors[:initiated_via]).to be_present
  end

  describe 'lifecycle' do
    it 'counts every non-terminal status as active' do
      described_class::ACTIVE_STATUSES.each do |status|
        expect(build(:maintenance_task_run, status: status)).to be_active
      end
    end

    it 'counts succeeded, errored and cancelled as terminal' do
      described_class::TERMINAL_STATUSES.each do |status|
        expect(build(:maintenance_task_run, status: status)).to be_terminal
      end
    end

    # An interrupted run has already been re-queued by the backend, so
    # offering an operator a resume button for it would enqueue a second one.
    it 'is resumable only after a pause or a failure' do
      expect(build(:maintenance_task_run, status: 'paused')).to be_resumable
      expect(build(:maintenance_task_run, status: 'errored')).to be_resumable
      expect(build(:maintenance_task_run, status: 'interrupted')).not_to be_resumable
      expect(build(:maintenance_task_run, status: 'succeeded')).not_to be_resumable
    end

    it 'can be cancelled while active but not once cancelling is under way' do
      expect(build(:maintenance_task_run, status: 'running')).to be_cancelable
      expect(build(:maintenance_task_run, status: 'cancelling')).not_to be_cancelable
      expect(build(:maintenance_task_run, status: 'succeeded')).not_to be_cancelable
    end
  end

  describe '#progress' do
    it 'is nil when the task could not count its collection' do
      expect(build(:maintenance_task_run, tick_count: 5, tick_total: nil).progress).to be_nil
    end

    it 'reports the share of the collection processed' do
      expect(build(:maintenance_task_run, tick_count: 5, tick_total: 20).progress).to eq(0.25)
    end

    # A collection that grows mid-run would otherwise report over 100%.
    it 'never exceeds one' do
      expect(build(:maintenance_task_run, tick_count: 30, tick_total: 20).progress).to eq(1.0)
    end
  end

  describe '#display_arguments' do
    before do
      stub_const('MaskedArgumentTask', Class.new(Spree::MaintenanceTask) do
        def self.name = 'MaskedArgumentTask'
        attribute :token, :string
        attribute :label, :string
        mask_attribute :token
      end)
      Spree.maintenance_tasks << 'MaskedArgumentTask'
    end

    after { Spree.maintenance_tasks.delete('MaskedArgumentTask') }

    it 'hides values the task marked as masked' do
      run = build(:maintenance_task_run, task_name: 'MaskedArgumentTask',
                                         arguments: { 'token' => 'secret', 'label' => 'visible' })

      expect(run.display_arguments['token']).to eq(Spree::MaintenanceTask::MASKED_VALUE)
      expect(run.display_arguments['label']).to eq('visible')
    end

    # The stored value is the run's own record of what it did, and a rerun
    # needs it — masking is a display concern only.
    it 'leaves the stored arguments untouched' do
      run = build(:maintenance_task_run, task_name: 'MaskedArgumentTask', arguments: { 'token' => 'secret' })
      run.display_arguments

      expect(run.arguments['token']).to eq('secret')
    end
  end

  describe '#task_class' do
    it 'is nil when the task is no longer registered' do
      expect(build(:maintenance_task_run, task_name: 'Gone::Task').task_class).to be_nil
    end
  end
end
