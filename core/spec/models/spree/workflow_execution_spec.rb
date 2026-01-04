require 'spec_helper'

RSpec.describe Spree::WorkflowExecution, type: :model do
  describe 'validations' do
    it 'requires workflow_id' do
      execution = build(:workflow_execution, workflow_id: nil)
      expect(execution).not_to be_valid
      expect(execution.errors[:workflow_id]).to be_present
    end

    it 'requires transaction_id' do
      execution = build(:workflow_execution, transaction_id: nil)
      execution.valid?
      # transaction_id is set by before_validation, so we need to clear it after
      execution.transaction_id = nil
      expect(execution).not_to be_valid
    end

    it 'requires valid status' do
      execution = build(:workflow_execution, status: 'invalid')
      expect(execution).not_to be_valid
      expect(execution.errors[:status]).to be_present
    end

    it 'enforces unique transaction_id' do
      create(:workflow_execution, transaction_id: 'unique-123')
      duplicate = build(:workflow_execution, transaction_id: 'unique-123')
      expect(duplicate).not_to be_valid
    end
  end

  describe 'defaults' do
    it 'generates transaction_id' do
      execution = create(:workflow_execution, transaction_id: nil)
      expect(execution.transaction_id).to be_present
    end

    it 'sets status to pending' do
      execution = create(:workflow_execution, status: nil)
      expect(execution.status).to eq('pending')
    end

    it 'initializes context as empty hash' do
      execution = create(:workflow_execution, context: nil)
      expect(execution.context).to eq({})
    end
  end

  describe 'associations' do
    it 'has many step_executions' do
      execution = create(:workflow_execution)
      step1 = create(:workflow_step_execution, workflow_execution: execution, position: 0)
      step2 = create(:workflow_step_execution, workflow_execution: execution, position: 1)

      expect(execution.step_executions).to contain_exactly(step1, step2)
    end

    it 'destroys step_executions on destroy' do
      execution = create(:workflow_execution)
      create(:workflow_step_execution, workflow_execution: execution, position: 0)

      expect { execution.destroy }.to change(Spree::WorkflowStepExecution, :count).by(-1)
    end

    it 'belongs to store optionally' do
      execution = create(:workflow_execution, store: nil)
      expect(execution).to be_valid
    end
  end

  describe 'scopes' do
    before do
      create(:workflow_execution, status: 'pending')
      create(:workflow_execution, status: 'running')
      create(:workflow_execution, status: 'completed')
      create(:workflow_execution, status: 'failed')
    end

    it '.pending returns pending executions' do
      expect(described_class.pending.count).to eq(1)
    end

    it '.running returns running executions' do
      expect(described_class.running.count).to eq(1)
    end

    it '.completed returns completed executions' do
      expect(described_class.completed.count).to eq(1)
    end

    it '.failed returns failed executions' do
      expect(described_class.failed.count).to eq(1)
    end

    it '.for_workflow filters by workflow_id' do
      create(:workflow_execution, workflow_id: 'order_fulfillment')
      create(:workflow_execution, workflow_id: 'return_processing')

      expect(described_class.for_workflow('order_fulfillment').count).to eq(1)
    end
  end

  describe 'status methods' do
    it '#pending? returns true for pending status' do
      execution = build(:workflow_execution, status: 'pending')
      expect(execution.pending?).to be true
    end

    it '#running? returns true for running status' do
      execution = build(:workflow_execution, status: 'running')
      expect(execution.running?).to be true
    end

    it '#waiting? returns true for waiting status' do
      execution = build(:workflow_execution, status: 'waiting')
      expect(execution.waiting?).to be true
    end

    it '#completed? returns true for completed status' do
      execution = build(:workflow_execution, status: 'completed')
      expect(execution.completed?).to be true
    end

    it '#failed? returns true for failed status' do
      execution = build(:workflow_execution, status: 'failed')
      expect(execution.failed?).to be true
    end

    it '#compensating? returns true for compensating status' do
      execution = build(:workflow_execution, status: 'compensating')
      expect(execution.compensating?).to be true
    end
  end

  describe '#can_resume?' do
    it 'returns true for waiting workflows' do
      execution = build(:workflow_execution, status: 'waiting')
      expect(execution.can_resume?).to be true
    end

    it 'returns false for completed workflows' do
      execution = build(:workflow_execution, status: 'completed')
      expect(execution.can_resume?).to be false
    end
  end

  describe '#progress_percentage' do
    it 'returns 0 for no steps' do
      execution = create(:workflow_execution)
      expect(execution.progress_percentage).to eq(0)
    end

    it 'calculates percentage based on completed steps' do
      execution = create(:workflow_execution)
      create(:workflow_step_execution, workflow_execution: execution, status: 'completed', position: 0)
      create(:workflow_step_execution, workflow_execution: execution, status: 'completed', position: 1)
      create(:workflow_step_execution, workflow_execution: execution, status: 'pending', position: 2)
      create(:workflow_step_execution, workflow_execution: execution, status: 'pending', position: 3)

      expect(execution.progress_percentage).to eq(50)
    end
  end

  describe '#current_step' do
    it 'returns the step matching current_step_id' do
      execution = create(:workflow_execution, current_step_id: 'process_payment')
      step = create(:workflow_step_execution, workflow_execution: execution, step_id: 'process_payment', position: 0)

      expect(execution.current_step).to eq(step)
    end
  end
end
