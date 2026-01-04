require 'spec_helper'

RSpec.describe Spree::WorkflowStepExecution, type: :model do
  let(:execution) { create(:workflow_execution) }

  describe 'validations' do
    it 'requires step_id' do
      step = build(:workflow_step_execution, step_id: nil)
      expect(step).not_to be_valid
    end

    it 'requires valid status' do
      step = build(:workflow_step_execution, status: 'invalid')
      expect(step).not_to be_valid
    end

    it 'requires position' do
      step = build(:workflow_step_execution, position: nil)
      expect(step).not_to be_valid
    end

    it 'requires position to be integer >= 0' do
      step = build(:workflow_step_execution, position: -1)
      expect(step).not_to be_valid
    end
  end

  describe 'defaults' do
    it 'sets status to pending' do
      step = create(:workflow_step_execution, workflow_execution: execution, status: nil, position: 0)
      expect(step.status).to eq('pending')
    end

    it 'sets attempts to 0' do
      step = create(:workflow_step_execution, workflow_execution: execution, position: 0)
      expect(step.attempts).to eq(0)
    end
  end

  describe 'associations' do
    it 'belongs to workflow_execution' do
      step = create(:workflow_step_execution, workflow_execution: execution, position: 0)
      expect(step.workflow_execution).to eq(execution)
    end
  end

  describe 'scopes' do
    before do
      create(:workflow_step_execution, workflow_execution: execution, status: 'pending', position: 0)
      create(:workflow_step_execution, workflow_execution: execution, status: 'running', position: 1)
      create(:workflow_step_execution, workflow_execution: execution, status: 'completed', position: 2)
      create(:workflow_step_execution, workflow_execution: execution, status: 'failed', position: 3)
    end

    it '.pending returns pending steps' do
      expect(described_class.pending.count).to eq(1)
    end

    it '.running returns running steps' do
      expect(described_class.running.count).to eq(1)
    end

    it '.completed returns completed steps' do
      expect(described_class.completed.count).to eq(1)
    end

    it '.failed returns failed steps' do
      expect(described_class.failed.count).to eq(1)
    end

    it '.ordered returns steps by position' do
      steps = described_class.ordered
      expect(steps.map(&:position)).to eq([0, 1, 2, 3])
    end

    it '.needs_compensation returns completed steps in reverse order' do
      steps = described_class.needs_compensation
      expect(steps.first.position).to be > steps.last.position
    end
  end

  describe 'status methods' do
    it '#pending? returns true for pending status' do
      step = build(:workflow_step_execution, status: 'pending')
      expect(step.pending?).to be true
    end

    it '#running? returns true for running status' do
      step = build(:workflow_step_execution, status: 'running')
      expect(step.running?).to be true
    end

    it '#completed? returns true for completed status' do
      step = build(:workflow_step_execution, status: 'completed')
      expect(step.completed?).to be true
    end

    it '#failed? returns true for failed status' do
      step = build(:workflow_step_execution, status: 'failed')
      expect(step.failed?).to be true
    end

    it '#compensated? returns true for compensated status' do
      step = build(:workflow_step_execution, status: 'compensated')
      expect(step.compensated?).to be true
    end

    it '#async? returns true when async flag is set' do
      step = build(:workflow_step_execution, async: true)
      expect(step.async?).to be true
    end
  end

  describe '#duration' do
    it 'returns nil if not started' do
      step = build(:workflow_step_execution, started_at: nil)
      expect(step.duration).to be_nil
    end

    it 'returns nil if not completed' do
      step = build(:workflow_step_execution, started_at: Time.current, completed_at: nil)
      expect(step.duration).to be_nil
    end

    it 'calculates duration in seconds' do
      started = Time.current
      completed = started + 5.seconds
      step = build(:workflow_step_execution, started_at: started, completed_at: completed)

      expect(step.duration).to be_within(0.1).of(5.0)
    end
  end

  describe '#mark_running!' do
    it 'updates status and timestamps' do
      step = create(:workflow_step_execution, workflow_execution: execution, position: 0)

      step.mark_running!

      expect(step.status).to eq('running')
      expect(step.started_at).to be_present
      expect(step.attempts).to eq(1)
    end

    it 'increments attempts on each call' do
      step = create(:workflow_step_execution, workflow_execution: execution, position: 0)

      step.mark_running!
      step.update!(status: 'pending')
      step.mark_running!

      expect(step.attempts).to eq(2)
    end
  end

  describe '#mark_completed!' do
    it 'updates status and stores output' do
      step = create(:workflow_step_execution, workflow_execution: execution, position: 0, status: 'running')

      step.mark_completed!(output: { result: 'success' })

      expect(step.status).to eq('completed')
      expect(step.output).to eq({ 'result' => 'success' })
      expect(step.completed_at).to be_present
    end

    it 'stores compensation data' do
      step = create(:workflow_step_execution, workflow_execution: execution, position: 0, status: 'running')

      step.mark_completed!(output: { result: 'success' }, compensation_data: { rollback: 123 })

      expect(step.compensation_data).to eq({ 'rollback' => 123 })
    end

    it 'clears previous errors' do
      step = create(:workflow_step_execution,
                    workflow_execution: execution,
                    position: 0,
                    status: 'running',
                    error_message: 'Previous error')

      step.mark_completed!(output: {})

      expect(step.error_message).to be_nil
      expect(step.error_class).to be_nil
    end
  end

  describe '#mark_failed!' do
    it 'stores error information' do
      step = create(:workflow_step_execution, workflow_execution: execution, position: 0, status: 'running')
      error = StandardError.new('Something went wrong')

      step.mark_failed!(error)

      expect(step.status).to eq('failed')
      expect(step.error_message).to eq('Something went wrong')
      expect(step.error_class).to eq('StandardError')
      expect(step.completed_at).to be_present
    end
  end

  describe '#mark_compensated!' do
    it 'updates status' do
      step = create(:workflow_step_execution, workflow_execution: execution, position: 0, status: 'completed')

      step.mark_compensated!

      expect(step.status).to eq('compensated')
      expect(step.completed_at).to be_present
    end
  end

  describe '#mark_compensation_failed!' do
    it 'stores compensation failure' do
      step = create(:workflow_step_execution, workflow_execution: execution, position: 0, status: 'completed')
      error = StandardError.new('Compensation failed')

      step.mark_compensation_failed!(error)

      expect(step.status).to eq('compensation_failed')
      expect(step.error_message).to include('Compensation failed')
    end
  end
end
