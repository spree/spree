require 'spec_helper'

RSpec.describe Spree::Workflows::Engine do
  # Create a test workflow with an async step
  let(:async_workflow_class) do
    Class.new(Spree::Workflows::Base) do
      workflow_id 'test_async_workflow'

      step :before_async do |input, context|
        success({ prepared: true })
      end

      step :async_step, async: true do |input, context|
        success({
          external_id: input[:external_id],
          confirmed: true
        })
      end.compensate do |data, context|
        context[:async_compensated] = true
      end

      step :after_async do |input, context|
        success({ completed: true })
      end
    end
  end

  before do
    Spree::Workflows.clear_registry!
    async_workflow_class # Register the workflow
  end

  after do
    Spree::Workflows.clear_registry!
  end

  describe '.complete_step', :db do
    let(:execution) do
      async_workflow_class.run_sync(input: { order_id: 1 })
      Spree::WorkflowExecution.last
    end

    before do
      # The sync run will pause at async step, leaving it in 'waiting' state
      execution.update!(status: 'waiting')
      execution.step_executions.find_by(step_id: 'async_step').update!(status: 'running')
    end

    it 'completes an async step' do
      result = described_class.complete_step(
        transaction_id: execution.transaction_id,
        step_id: 'async_step',
        output: { external_id: 'ext_123' }
      )

      step = execution.reload.step_executions.find_by(step_id: 'async_step')
      expect(step.status).to eq('completed')
      expect(step.output['external_id']).to eq('ext_123')
    end

    it 'enqueues job to continue workflow' do
      expect {
        described_class.complete_step(
          transaction_id: execution.transaction_id,
          step_id: 'async_step',
          output: {}
        )
      }.to have_enqueued_job(Spree::Workflows::ExecuteWorkflowJob)
    end

    it 'raises error for non-waiting workflow' do
      execution.update!(status: 'completed')

      expect {
        described_class.complete_step(
          transaction_id: execution.transaction_id,
          step_id: 'async_step',
          output: {}
        )
      }.to raise_error(Spree::Workflows::WorkflowNotResumableError)
    end

    it 'raises error for non-async step' do
      execution.step_executions.find_by(step_id: 'async_step').update!(async: false)

      expect {
        described_class.complete_step(
          transaction_id: execution.transaction_id,
          step_id: 'async_step',
          output: {}
        )
      }.to raise_error(Spree::Workflows::WorkflowNotResumableError)
    end

    it 'raises error for unknown transaction' do
      expect {
        described_class.complete_step(
          transaction_id: 'unknown',
          step_id: 'async_step',
          output: {}
        )
      }.to raise_error(Spree::Workflows::WorkflowNotFoundError)
    end
  end

  describe '.fail_step', :db do
    let(:execution) do
      async_workflow_class.run_sync(input: {})
      Spree::WorkflowExecution.last.tap do |e|
        e.update!(status: 'waiting')
        e.step_executions.find_by(step_id: 'async_step').update!(status: 'running')
      end
    end

    it 'marks step as failed' do
      described_class.fail_step(
        transaction_id: execution.transaction_id,
        step_id: 'async_step',
        error: 'External service failed'
      )

      step = execution.reload.step_executions.find_by(step_id: 'async_step')
      expect(step.status).to eq('failed')
      expect(step.error_message).to eq('External service failed')
    end

    it 'stores compensation data' do
      described_class.fail_step(
        transaction_id: execution.transaction_id,
        step_id: 'async_step',
        error: 'Failed',
        compensation_data: { cleanup_id: 'xyz' }
      )

      step = execution.reload.step_executions.find_by(step_id: 'async_step')
      expect(step.compensation_data['cleanup_id']).to eq('xyz')
    end
  end

  describe '.retry', :db do
    let(:failed_workflow) do
      Class.new(Spree::Workflows::Base) do
        workflow_id 'test_failing_workflow'

        step :will_fail do |input, context|
          if context[:retry_count].to_i > 0
            success({ fixed: true })
          else
            context[:retry_count] = context[:retry_count].to_i + 1
            failure('First attempt fails')
          end
        end
      end
    end

    before { failed_workflow }

    it 'retries a failed workflow' do
      result = failed_workflow.run_sync(input: {})
      expect(result.failure?).to be true

      retry_result = described_class.retry(transaction_id: result.transaction_id)
      expect(retry_result.pending?).to be true
    end

    it 'resets failed step to pending' do
      result = failed_workflow.run_sync(input: {})
      failed_step = result.step_executions.find_by(step_id: 'will_fail')
      expect(failed_step.status).to eq('failed')

      described_class.retry(transaction_id: result.transaction_id)

      failed_step.reload
      expect(failed_step.status).to eq('pending')
    end

    it 'raises error for non-failed workflow' do
      simple_workflow = Class.new(Spree::Workflows::Base) do
        workflow_id 'simple'
        step(:ok) { |_, _| success({}) }
      end

      result = simple_workflow.run_sync(input: {})

      expect {
        described_class.retry(transaction_id: result.transaction_id)
      }.to raise_error(Spree::Workflows::WorkflowNotResumableError)
    end
  end

  describe '.cancel', :db do
    let(:execution) do
      async_workflow_class.run_sync(input: {})
      Spree::WorkflowExecution.last.tap do |e|
        e.update!(status: 'waiting')
      end
    end

    it 'cancels a waiting workflow' do
      result = described_class.cancel(
        transaction_id: execution.transaction_id,
        reason: 'User requested cancellation'
      )

      expect(result.failure?).to be true
      expect(result.error).to eq('User requested cancellation')
    end

    it 'skips pending steps' do
      described_class.cancel(transaction_id: execution.transaction_id)

      pending_steps = execution.reload.step_executions.where(status: 'skipped')
      expect(pending_steps).to be_present
    end

    it 'raises error for completed workflow' do
      execution.update!(status: 'completed')

      expect {
        described_class.cancel(transaction_id: execution.transaction_id)
      }.to raise_error(Spree::Workflows::WorkflowNotResumableError)
    end
  end

  describe '.status', :db do
    it 'returns execution result for existing workflow' do
      result = async_workflow_class.run_sync(input: {})

      status = described_class.status(transaction_id: result.transaction_id)

      expect(status).to be_a(Spree::Workflows::ExecutionResult)
      expect(status.transaction_id).to eq(result.transaction_id)
    end

    it 'returns nil for unknown transaction' do
      status = described_class.status(transaction_id: 'unknown')

      expect(status).to be_nil
    end
  end

  describe '.list_executions', :db do
    before do
      3.times { async_workflow_class.run_sync(input: {}) }
    end

    it 'lists executions for a workflow' do
      executions = described_class.list_executions(workflow_id: 'test_async_workflow')

      expect(executions.size).to eq(3)
      expect(executions).to all(be_a(Spree::Workflows::ExecutionResult))
    end

    it 'filters by status' do
      Spree::WorkflowExecution.last.update!(status: 'failed')

      executions = described_class.list_executions(
        workflow_id: 'test_async_workflow',
        status: 'failed'
      )

      expect(executions.size).to eq(1)
    end

    it 'respects limit' do
      executions = described_class.list_executions(
        workflow_id: 'test_async_workflow',
        limit: 2
      )

      expect(executions.size).to eq(2)
    end
  end

  describe '.subscribe and .publish' do
    it 'notifies subscribers of events' do
      received_events = []

      described_class.subscribe(
        transaction_id: 'tx-123',
        subscriber_id: 'test-subscriber'
      ) { |event| received_events << event }

      described_class.publish(
        transaction_id: 'tx-123',
        type: :completed,
        data: { output: { success: true } }
      )

      expect(received_events.size).to eq(1)
      expect(received_events.first[:type]).to eq(:completed)
    end

    it 'handles subscriber errors gracefully' do
      described_class.subscribe(
        transaction_id: 'tx-123',
        subscriber_id: 'failing-subscriber'
      ) { |event| raise 'Subscriber error' }

      expect {
        described_class.publish(
          transaction_id: 'tx-123',
          type: :completed,
          data: {}
        )
      }.not_to raise_error
    end
  end

  describe '.unsubscribe' do
    it 'removes subscriber' do
      received = false

      described_class.subscribe(
        transaction_id: 'tx-123',
        subscriber_id: 'test-subscriber'
      ) { |_| received = true }

      described_class.unsubscribe(
        transaction_id: 'tx-123',
        subscriber_id: 'test-subscriber'
      )

      described_class.publish(transaction_id: 'tx-123', type: :test, data: {})

      expect(received).to be false
    end
  end

  describe '.cleanup', :db do
    before do
      3.times { async_workflow_class.run_sync(input: {}) }
      Spree::WorkflowExecution.update_all(created_at: 60.days.ago)
    end

    it 'deletes old executions' do
      expect {
        described_class.cleanup(older_than: 30.days)
      }.to change(Spree::WorkflowExecution, :count).by(-3)
    end

    it 'respects status filter' do
      Spree::WorkflowExecution.first.update!(status: 'running')

      count = described_class.cleanup(
        older_than: 30.days,
        statuses: %w[completed failed]
      )

      expect(count).to eq(2)
    end
  end
end
