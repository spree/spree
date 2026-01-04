require 'spec_helper'

RSpec.describe Spree::Workflows::Hookable do
  # Test workflow with hooks
  let(:workflow_with_hooks) do
    Class.new(Spree::Workflows::Base) do
      workflow_id 'test_hookable_workflow'

      step :first_step do |input, context|
        context[:first_done] = true
        success({ step: 1 })
      end

      define_hook :after_first_step

      step :second_step do |input, context|
        context[:second_done] = true
        success({ step: 2 })
      end

      define_hook :after_second_step

      step :third_step do |input, context|
        success({ step: 3 })
      end
    end
  end

  before do
    Spree::Workflows.clear_registry!
  end

  after do
    Spree::Workflows.clear_registry!
  end

  describe '.define_hook' do
    it 'registers the hook' do
      expect(workflow_with_hooks.defined_hooks).to include(:after_first_step, :after_second_step)
    end

    it 'adds hook to execution sequence' do
      sequence = workflow_with_hooks.execution_sequence
      hook_items = sequence.select { |item| item.is_a?(Hash) && item[:hook] }

      expect(hook_items.map { |h| h[:hook] }).to eq([:after_first_step, :after_second_step])
    end

    it 'preserves step order with hooks interleaved' do
      sequence = workflow_with_hooks.execution_sequence

      # Should be: step, hook, step, hook, step
      expect(sequence[0]).to be_a(Spree::Workflows::Step)
      expect(sequence[0].id).to eq('first_step')

      expect(sequence[1]).to eq({ hook: :after_first_step })

      expect(sequence[2]).to be_a(Spree::Workflows::Step)
      expect(sequence[2].id).to eq('second_step')

      expect(sequence[3]).to eq({ hook: :after_second_step })

      expect(sequence[4]).to be_a(Spree::Workflows::Step)
      expect(sequence[4].id).to eq('third_step')
    end
  end

  describe '.hooks' do
    it 'returns a HookRegistry' do
      expect(workflow_with_hooks.hooks).to be_a(Spree::Workflows::HookRegistry)
    end

    it 'allows registering a handler' do
      handler_called = false

      workflow_with_hooks.hooks.after_first_step do |context|
        handler_called = true
      end

      expect(workflow_with_hooks.hook_handler_for(:after_first_step)).to be_present
    end

    it 'raises error for unknown hook' do
      expect {
        workflow_with_hooks.hooks.unknown_hook { }
      }.to raise_error(NoMethodError)
    end
  end

  describe 'hook with compensation' do
    it 'registers compensation handler' do
      workflow_with_hooks.hooks.after_first_step do |context|
        context[:hook_ran] = true
      end.compensate do |context|
        context[:hook_compensated] = true
      end

      handler = workflow_with_hooks.hook_handler_for(:after_first_step)
      expect(handler.compensatable?).to be true
    end
  end

  describe 'hook execution', :db do
    it 'executes hooks between steps' do
      hook_context = nil

      workflow_with_hooks.hooks.after_first_step do |context|
        hook_context = context.to_h.dup
        context[:hook_executed] = true
      end

      result = workflow_with_hooks.run_sync(input: { test: true })

      expect(result.success?).to be true
      expect(hook_context['first_done']).to be true
      expect(result.output['hook_executed']).to be true
    end

    it 'executes multiple hooks in order' do
      execution_order = []

      workflow_with_hooks.hooks.after_first_step do |context|
        execution_order << :hook_1
      end

      workflow_with_hooks.hooks.after_second_step do |context|
        execution_order << :hook_2
      end

      workflow_with_hooks.run_sync(input: {})

      expect(execution_order).to eq([:hook_1, :hook_2])
    end

    it 'hook failure triggers compensation' do
      compensated = false

      workflow_with_hooks.hooks.after_second_step do |context|
        raise 'Hook failed!'
      end

      # Add compensation to first step
      workflow_with_hooks.steps.first.compensate do |data, context|
        compensated = true
      end

      result = workflow_with_hooks.run_sync(input: {})

      expect(result.failure?).to be true
      expect(result.error).to include('Hook failed')
      expect(compensated).to be true
    end

    it 'compensates hooks in reverse order on failure' do
      compensation_order = []

      workflow_with_hooks.hooks.after_first_step do |context|
        # runs
      end.compensate do |context|
        compensation_order << :hook_1_compensated
      end

      workflow_with_hooks.hooks.after_second_step do |context|
        # runs
      end.compensate do |context|
        compensation_order << :hook_2_compensated
      end

      # Make third step fail
      failing_workflow = Class.new(workflow_with_hooks) do
        # Override third step to fail
        steps.last.instance_variable_set(:@handler, proc { |_, _|
          failure('Third step failed')
        })
      end
      failing_workflow.workflow_id 'test_failing_hooks'

      # Copy hooks
      failing_workflow.register_hook_handler(:after_first_step,
        handler: workflow_with_hooks.hook_handler_for(:after_first_step).handler,
        compensation: workflow_with_hooks.hook_handler_for(:after_first_step).compensation
      )
      failing_workflow.register_hook_handler(:after_second_step,
        handler: workflow_with_hooks.hook_handler_for(:after_second_step).handler,
        compensation: workflow_with_hooks.hook_handler_for(:after_second_step).compensation
      )

      failing_workflow.run_sync(input: {})

      expect(compensation_order).to eq([:hook_2_compensated, :hook_1_compensated])
    end
  end

  describe 'HookHandler' do
    let(:handler) do
      Spree::Workflows::HookHandler.new(
        name: :test_hook,
        handler: ->(ctx) { ctx[:executed] = true },
        compensation: ->(ctx) { ctx[:compensated] = true }
      )
    end

    describe '#execute' do
      it 'calls the handler with context' do
        context = Spree::Workflows::Context.new

        handler.execute(context)

        expect(context[:executed]).to be true
      end

      it 'raises HookExecutionError on failure' do
        failing_handler = Spree::Workflows::HookHandler.new(
          name: :failing,
          handler: ->(_) { raise 'Boom!' }
        )

        expect {
          failing_handler.execute(Spree::Workflows::Context.new)
        }.to raise_error(Spree::Workflows::HookExecutionError, /Boom/)
      end
    end

    describe '#compensate' do
      it 'calls the compensation with context' do
        context = Spree::Workflows::Context.new

        handler.compensate(context)

        expect(context[:compensated]).to be true
      end

      it 'does nothing without compensation' do
        no_comp_handler = Spree::Workflows::HookHandler.new(
          name: :no_comp,
          handler: ->(_) {}
        )

        expect { no_comp_handler.compensate(Spree::Workflows::Context.new) }.not_to raise_error
      end
    end

    describe '#compensatable?' do
      it 'returns true when compensation is present' do
        expect(handler.compensatable?).to be true
      end

      it 'returns false when no compensation' do
        no_comp = Spree::Workflows::HookHandler.new(name: :x, handler: ->(_) {})
        expect(no_comp.compensatable?).to be false
      end
    end
  end
end
