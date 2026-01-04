require 'spec_helper'

RSpec.describe Spree::Workflows::Subscriber do
  # Test workflow
  let(:test_workflow) do
    Class.new(Spree::Workflows::Base) do
      workflow_id 'test_subscriber_workflow'

      step :process do |input, context|
        success({ processed: true, input: input })
      end
    end
  end

  # Simple subscriber
  let(:simple_subscriber) do
    Class.new(described_class) do
      subscribes_to 'order.completed'
      triggers_workflow 'test_subscriber_workflow'

      def build_input(event)
        { order_id: event.payload['id'] }
      end
    end
  end

  # Conditional subscriber
  let(:conditional_subscriber) do
    Class.new(described_class) do
      subscribes_to 'order.completed'
      triggers_workflow 'test_subscriber_workflow'

      def should_trigger?(event)
        event.payload['total'].to_f > 100
      end

      def build_input(event)
        { order_id: event.payload['id'], total: event.payload['total'] }
      end
    end
  end

  # Multi-workflow subscriber
  let(:multi_workflow_subscriber) do
    Class.new(described_class) do
      subscribes_to 'order.completed', 'order.canceled'

      on 'order.completed', workflow: 'test_subscriber_workflow'
      on 'order.canceled', workflow: 'test_cancellation_workflow'

      def build_input(event)
        { order_id: event.payload['id'] }
      end
    end
  end

  let(:event) do
    Spree::Event.new(
      name: 'order.completed',
      payload: { 'id' => 123, 'number' => 'R123456', 'total' => '150.00', 'store_id' => 1 },
      metadata: {}
    )
  end

  before do
    Spree::Workflows.clear_registry!
    test_workflow # Register the workflow
  end

  after do
    Spree::Workflows.clear_registry!
  end

  describe '.triggers_workflow' do
    it 'sets the triggered workflow' do
      expect(simple_subscriber.triggered_workflow).to eq('test_subscriber_workflow')
    end
  end

  describe '.on with workflow option' do
    it 'maps events to workflows' do
      expect(multi_workflow_subscriber.event_workflows).to eq({
        'order.completed' => 'test_subscriber_workflow',
        'order.canceled' => 'test_cancellation_workflow'
      })
    end
  end

  describe '#call', :db do
    context 'with simple subscriber' do
      it 'triggers the workflow' do
        expect {
          simple_subscriber.new.call(event)
        }.to change(Spree::WorkflowExecution, :count).by(1)
      end

      it 'passes built input to workflow' do
        simple_subscriber.new.call(event)

        execution = Spree::WorkflowExecution.last
        expect(execution.input['order_id']).to eq(123)
      end

      it 'returns execution result' do
        result = simple_subscriber.new.call(event)

        expect(result).to be_a(Spree::Workflows::ExecutionResult)
      end
    end

    context 'with conditional subscriber' do
      it 'triggers when condition is met' do
        expect {
          conditional_subscriber.new.call(event)
        }.to change(Spree::WorkflowExecution, :count).by(1)
      end

      it 'does not trigger when condition is not met' do
        low_value_event = Spree::Event.new(
          name: 'order.completed',
          payload: { 'id' => 456, 'total' => '50.00' },
          metadata: {}
        )

        expect {
          conditional_subscriber.new.call(low_value_event)
        }.not_to change(Spree::WorkflowExecution, :count)
      end
    end

    context 'with multi-workflow subscriber' do
      let(:cancellation_workflow) do
        Class.new(Spree::Workflows::Base) do
          workflow_id 'test_cancellation_workflow'
          step(:cancel) { |_, _| success({}) }
        end
      end

      before { cancellation_workflow }

      it 'triggers correct workflow for order.completed' do
        multi_workflow_subscriber.new.call(event)

        execution = Spree::WorkflowExecution.last
        expect(execution.workflow_id).to eq('test_subscriber_workflow')
      end

      it 'triggers correct workflow for order.canceled' do
        cancel_event = Spree::Event.new(
          name: 'order.canceled',
          payload: { 'id' => 789 },
          metadata: {}
        )

        multi_workflow_subscriber.new.call(cancel_event)

        execution = Spree::WorkflowExecution.last
        expect(execution.workflow_id).to eq('test_cancellation_workflow')
      end
    end

    context 'with sync mode' do
      let(:sync_subscriber) do
        Class.new(described_class) do
          subscribes_to 'order.completed', async: false
          triggers_workflow 'test_subscriber_workflow', mode: :sync

          def build_input(event)
            { order_id: event.payload['id'] }
          end
        end
      end

      it 'runs workflow synchronously' do
        result = sync_subscriber.new.call(event)

        expect(result.success?).to be true
        expect(result.output['processed']).to be true
      end
    end

    context 'when workflow not found' do
      let(:bad_subscriber) do
        Class.new(described_class) do
          subscribes_to 'order.completed'
          triggers_workflow 'nonexistent_workflow'
        end
      end

      it 'reports error and does not raise' do
        expect(Rails.error).to receive(:report).with(
          kind_of(Spree::Workflows::WorkflowNotFoundError),
          hash_including(:context)
        )

        expect {
          bad_subscriber.new.call(event)
        }.not_to raise_error
      end
    end
  end

  describe '#build_metadata' do
    it 'includes event information' do
      subscriber = simple_subscriber.new
      metadata = subscriber.build_metadata(event)

      expect(metadata[:triggered_by_event]).to eq('order.completed')
      expect(metadata[:event_id]).to eq(event.id)
    end
  end

  describe 'inheritance from Spree::Subscriber' do
    it 'inherits subscription patterns' do
      expect(simple_subscriber.subscription_patterns).to eq(['order.completed'])
    end

    it 'can use async: false option' do
      sync_class = Class.new(described_class) do
        subscribes_to 'order.completed', async: false
        triggers_workflow 'test'
      end

      expect(sync_class.subscription_options[:async]).to be false
    end
  end
end
