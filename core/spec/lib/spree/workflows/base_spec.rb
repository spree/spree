require 'spec_helper'

RSpec.describe Spree::Workflows::Base do
  # Create test workflow classes for each test
  let(:simple_workflow_class) do
    Class.new(described_class) do
      workflow_id 'test_simple_workflow'

      step :first_step do |input, context|
        context[:first_ran] = true
        success({ value: input[:x] + 1 })
      end

      step :second_step do |input, context|
        context[:second_ran] = true
        success({ final: input[:value] * 2 })
      end
    end
  end

  let(:workflow_with_compensation) do
    Class.new(described_class) do
      workflow_id 'test_compensation_workflow'

      step :create_resource do |input, context|
        success(
          { resource_id: 123 },
          { resource_id: 123 }
        )
      end.compensate do |data, context|
        context[:compensated_resource] = data[:resource_id]
      end

      step :failing_step do |input, context|
        failure('Intentional failure')
      end
    end
  end

  before do
    # Clear registry before each test
    Spree::Workflows.clear_registry!
  end

  after do
    Spree::Workflows.clear_registry!
  end

  describe '.workflow_id' do
    it 'sets and registers the workflow' do
      simple_workflow_class

      expect(simple_workflow_class.workflow_id).to eq('test_simple_workflow')
      expect(Spree::Workflows.find('test_simple_workflow')).to eq(simple_workflow_class)
    end
  end

  describe '.step' do
    it 'defines steps' do
      expect(simple_workflow_class.steps.size).to eq(2)
      expect(simple_workflow_class.steps.map(&:id)).to eq(%w[first_step second_step])
    end

    it 'allows compensation definition' do
      expect(workflow_with_compensation.steps.first.compensatable?).to be true
    end
  end

  describe '.find_step' do
    it 'finds step by id' do
      step = simple_workflow_class.find_step('first_step')

      expect(step).to be_a(Spree::Workflows::Step)
      expect(step.id).to eq('first_step')
    end

    it 'returns nil for unknown step' do
      step = simple_workflow_class.find_step('unknown')

      expect(step).to be_nil
    end
  end

  describe '.run_sync', :db do
    it 'executes workflow synchronously' do
      result = simple_workflow_class.run_sync(input: { x: 5 })

      expect(result).to be_a(Spree::Workflows::ExecutionResult)
      expect(result.success?).to be true
      expect(result.output['final']).to eq(12) # (5+1)*2
    end

    it 'creates execution record' do
      expect {
        simple_workflow_class.run_sync(input: { x: 1 })
      }.to change(Spree::WorkflowExecution, :count).by(1)
    end

    it 'creates step execution records' do
      result = simple_workflow_class.run_sync(input: { x: 1 })

      expect(result.step_executions.count).to eq(2)
      expect(result.step_executions.all?(&:completed?)).to be true
    end

    it 'handles step failures and runs compensation' do
      result = workflow_with_compensation.run_sync(input: {})

      expect(result.failure?).to be true
      expect(result.error).to eq('Intentional failure')

      # Check compensation ran
      first_step = result.step_executions.find_by(step_id: 'create_resource')
      expect(first_step.status).to eq('compensated')
    end
  end

  describe '.run', :db do
    it 'enqueues workflow job' do
      expect {
        simple_workflow_class.run(input: { x: 1 })
      }.to have_enqueued_job(Spree::Workflows::ExecuteWorkflowJob)
    end

    it 'returns execution result with transaction_id' do
      result = simple_workflow_class.run(input: { x: 1 })

      expect(result).to be_a(Spree::Workflows::ExecutionResult)
      expect(result.transaction_id).to be_present
      expect(result.pending?).to be true
    end
  end

  describe '.find_execution', :db do
    it 'finds execution by transaction_id' do
      result = simple_workflow_class.run_sync(input: { x: 1 })

      found = simple_workflow_class.find_execution(result.transaction_id)

      expect(found).to be_a(Spree::Workflows::ExecutionResult)
      expect(found.transaction_id).to eq(result.transaction_id)
    end

    it 'returns nil for unknown transaction' do
      simple_workflow_class

      found = simple_workflow_class.find_execution('unknown-id')

      expect(found).to be_nil
    end
  end

  describe 'inheritance' do
    it 'inherits steps from parent' do
      parent = simple_workflow_class
      child = Class.new(parent) do
        workflow_id 'child_workflow'

        step :third_step do |input, context|
          success({ extra: true })
        end
      end

      expect(child.steps.size).to eq(3)
      expect(child.steps.map(&:id)).to include('first_step', 'second_step', 'third_step')
    end
  end
end
