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

    it 'counts succeeded, errored and cancelled as finished' do
      %w[succeeded errored cancelled].each do |status|
        expect(build(:maintenance_task_run, status: status)).not_to be_active
      end
    end
  end

  describe '#duration' do
    let(:started_at) { 2.hours.ago }

    it 'counts the time since the last checkpoint while a worker holds the run' do
      run = build(:maintenance_task_run, status: 'running', time_running: 30, started_at: started_at,
                                         updated_at: 10.seconds.ago)

      expect(run.duration).to be_within(1).of(40)
    end

    # A run that waited an hour in the queue after its time slice did 30
    # seconds of work, not an hour and a half.
    it 'stops counting while the run waits in the queue' do
      run = build(:maintenance_task_run, status: 'interrupted', time_running: 30, started_at: started_at,
                                         updated_at: 1.hour.ago)

      expect(run.duration).to eq(30)
    end
  end

  describe '#task_api_type' do
    it 'is the short name the API identifies the task by' do
      run = build(:maintenance_task_run, task_name: 'Spree::MaintenanceTasks::Upgrade::CaptureMethods')

      expect(run.task_api_type).to eq('capture_methods')
    end

    it 'is shortened the same way for a task that is no longer registered' do
      expect(build(:maintenance_task_run, task_name: 'Gone::OldTask').task_api_type).to eq('old_task')
    end
  end

  describe '#task_class' do
    it 'is nil when the task is no longer registered' do
      expect(build(:maintenance_task_run, task_name: 'Gone::Task').task_class).to be_nil
    end
  end
end
