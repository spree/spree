require 'spec_helper'

RSpec.describe Spree::Workflow do
  before { Spree.hooks.clear! }
  after { Spree.hooks.clear! }

  def build_workflow(&block)
    workflow = Class.new(Spree::Workflow) do
      def self.name = 'Spree::Testing::SampleWorkflow'
      workflow_key 'testing.sample_workflow'
      class_eval(&block)
    end
    stub_const('Spree::Testing::SampleWorkflow', workflow)
    workflow
  end

  describe 'argument contracts' do
    it 'validates required arguments, applies defaults, and rejects unknown keys' do
      workflow = build_workflow do
        argument :subject
        argument :quantity, default: 2
        step :inspect_inputs, provides: [:seen]
        def inspect_inputs = { seen: [context.subject, context.quantity] }
      end

      expect(workflow.call(subject: 'a').value.seen).to eq(['a', 2])
      expect(workflow.call(subject: 'a', quantity: 5).value.seen).to eq(['a', 5])
      expect { workflow.call(quantity: 1) }.to raise_error(Spree::Workflow::ContractError, /missing required argument subject/)
      expect { workflow.call(subject: 'a', bogus: 1) }.to raise_error(Spree::Workflow::ContractError, /unknown argument bogus/)
    end

    it 'validates declared argument types at the call boundary without coercing' do
      workflow = build_workflow do
        argument :cart, Spree::Cart
        argument :quantity, Integer, default: 1
        argument :confirmed, :boolean, default: false
        step :noop
        def noop = nil
      end

      cart = build(:cart)
      expect(workflow.call(cart: cart)).to be_success
      expect(workflow.call(cart: cart, quantity: 3, confirmed: true)).to be_success
      expect { workflow.call(cart: 'cart_123') }
        .to raise_error(Spree::Workflow::ContractError, /expected cart to be Spree::Cart, got String/)
      expect { workflow.call(cart: cart, quantity: '3') }
        .to raise_error(Spree::Workflow::ContractError, /expected quantity to be Integer, got String/)
      expect { workflow.call(cart: cart, confirmed: 1) }
        .to raise_error(Spree::Workflow::ContractError, /expected confirmed to be boolean, got Integer/)
    end

    it 'accepts any member of a union type and skips nil optionals' do
      workflow = build_workflow do
        argument :owner, [Spree::Cart, Spree::Order], default: nil
        step :noop
        def noop = nil
      end

      expect(workflow.call).to be_success
      expect(workflow.call(owner: build(:order))).to be_success
      expect { workflow.call(owner: 42) }
        .to raise_error(Spree::Workflow::ContractError, /expected owner to be Spree::Cart \| Spree::Order, got Integer/)
    end

    it 'maps deprecated aliases onto canonical keys with a warning' do
      workflow = build_workflow do
        argument :cart
        alias_argument order: :cart, deprecated: true
        step :read, provides: [:value]
        def read = { value: context.cart }
      end

      expect(Spree::Deprecation).to receive(:warn).with(/order: is deprecated/)
      expect(workflow.call(order: 'the-cart').value.value).to eq('the-cart')
    end
  end

  describe 'steps and context' do
    it 'threads declared outs through real context readers' do
      workflow = build_workflow do
        argument :base
        step :double, provides: [:doubled]
        step :describe, provides: [:text]
        def double = { doubled: context.base * 2 }
        def describe = { text: "got #{context.doubled}" }
      end

      result = workflow.call(base: 21)
      expect(result).to be_success
      expect(result.value.text).to eq('got 42')
      expect(result.value.to_h).to include(base: 21, doubled: 42)
      result.value => { doubled: }
      expect(doubled).to eq(42)
    end

    it 'raises a teaching error for unknown context keys and undeclared outs' do
      workflow = build_workflow do
        argument :base
        step :bad, provides: [:declared]
        def bad = { undeclared: 1 }
      end
      expect { workflow.call(base: 1) }.to raise_error(Spree::Workflow::ContractError, /undeclared keys undeclared/)

      workflow2 = build_workflow do
        argument :base
        step :peek, provides: []
        def peek = context.missing_key && {}
      end
      expect { workflow2.call(base: 1) }.to raise_error(NoMethodError, /Unknown context key :missing_key — available: base/)
    end

    it 'ignores incidental hashes from steps that declare no provides' do
      workflow = build_workflow do
        argument :base
        step :side_effect
        step :peek, provides: [:seen]
        def side_effect = { junk: 1 }
        def peek = { seen: context.key?(:junk) }
      end

      expect(workflow.call(base: 1).value.seen).to be(false)
    end

    it 'supports conditional steps, failure short-circuit, and halt_with' do
      workflow = build_workflow do
        argument :mode
        step :maybe_fail, if: -> { context.mode == :fail }
        step :maybe_halt, provides: [:early], halt_with: :early
        step :after, provides: [:reached]
        def maybe_fail = failure('nope')
        def maybe_halt = { early: (context.mode == :halt ? 'halted' : nil) }
        def after = { reached: true }
      end

      expect(workflow.call(mode: :fail)).to be_failure
      halted = workflow.call(mode: :halt)
      expect(halted).to be_success
      expect(halted.value).to eq('halted')
      expect(workflow.call(mode: :run).value.reached).to be(true)
    end

    it 'delegates with: steps and merges their kwargs from the context' do
      collaborator = Class.new do
        prepend Spree::ServiceModule::Base
        def call(base:)
          success(tripled: base * 3)
        end
      end

      workflow = build_workflow do
        argument :base
        step :triple, with: -> { @collaborator }, provides: [:tripled]
      end
      instance = workflow.new
      instance.instance_variable_set(:@collaborator, collaborator)
      result = instance.call(base: 3)
      expect(result.value.tripled).to eq(9)
    end
  end

  describe 'transactions and undo' do
    it 'rolls back a transaction group on failure and runs earlier undos' do
      undo_log = []
      workflow = build_workflow do
        argument :product
        step :outside_work, on_flow_failure: :undo_outside
        transaction do
          step :rename
          step :explode
        end
        define_method(:outside_work) { nil }
        define_method(:undo_outside) { undo_log << :undone }
        def rename = context.product.update!(name: 'Renamed') && nil
        def explode = failure('boom')
      end

      product = create(:product, name: 'Original')
      result = workflow.call(product: product)

      expect(result).to be_failure
      expect(product.reload.name).to eq('Original')
      expect(undo_log).to eq([:undone])
    end

    it 'runs undos in reverse order on exceptions' do
      undo_log = []
      workflow = build_workflow do
        argument :subject
        step :first,  on_flow_failure: :undo_first
        step :second, on_flow_failure: :undo_second
        step :third
        define_method(:first)  { nil }
        define_method(:second) { nil }
        define_method(:undo_first)  { undo_log << :first }
        define_method(:undo_second) { undo_log << :second }
        def third = raise('io blew up')
      end

      expect { workflow.call(subject: 1) }.to raise_error('io blew up')
      expect(undo_log).to eq([:second, :first])
    end

    it 'forbids external_step inside a transaction block at definition time' do
      expect do
        build_workflow do
          argument :subject
          transaction do
            external_step :charge
          end
        end
      end.to raise_error(Spree::Workflow::ContractError, /external_step charge cannot be declared inside a transaction/)
    end

    it 'converts declared exceptions into failures and re-raises the rest' do
      workflow = build_workflow do
        argument :subject
        rescue_from ArgumentError do |error|
          failure(context.subject, "handled: #{error.message}")
        end
        step :explode
        def explode = raise(context.subject == :known ? ArgumentError.new('bad input') : 'unknown boom')
      end

      result = workflow.call(subject: :known)
      expect(result).to be_failure
      expect(result.error.to_s).to eq('handled: bad input')

      expect { workflow.call(subject: :other) }.to raise_error('unknown boom')
    end

    it 'holds the declared row lock around the group' do
      workflow = build_workflow do
        argument :product
        transaction lock: :product do
          step :touch_name
        end
        def touch_name = context.product.update!(name: 'Locked') && nil
      end

      product = create(:product)
      expect(product).to receive(:with_lock).and_call_original
      workflow.call(product: product)
      expect(product.reload.name).to eq('Locked')
    end
  end

  describe 'hooks' do
    it 'dispatches registered handlers with the context and computes contracts' do
      workflow = build_workflow do
        argument :subject
        step :produce, provides: [:artifact]
        run_hooks :after_produce
        def produce = { artifact: 'thing' }
      end

      seen = nil
      Spree.hooks.register('testing.sample_workflow.after_produce') { |hook_context| seen = hook_context.artifact }
      workflow.call(subject: 1)

      expect(seen).to eq('thing')
      expect(workflow.hook_contract(:after_produce)).to contain_exactly(:subject, :artifact)
      expect(Spree.hooks.contract('testing.sample_workflow.after_produce')).to contain_exactly(:subject, :artifact)
    end

    it 'validates registrations against declared hooks at boot' do
      build_workflow do
        argument :subject
        run_hooks :real_hook
      end
      Spree.hooks.register('testing.sample_workflow.real_hook', 'SomeHandler')
      expect(Spree.hooks.validate!).to be(true)

      Spree.hooks.register('testing.sample_workflow.typo_hook', 'SomeHandler')
      expect { Spree.hooks.validate! }.to raise_error(Spree::Hooks::UnknownHookError, /declares no hook 'typo_hook'/)
    end

    it 'dedupes class-name registrations' do
      build_workflow do
        argument :subject
        run_hooks :point
      end
      Spree.hooks.register('testing.sample_workflow.point', 'MyHandler')
      Spree.hooks.register('testing.sample_workflow.point', 'MyHandler')

      expect(Spree.hooks.keys.count { |k| k == 'testing.sample_workflow.point' }).to eq(1)
      handler = Class.new { def call = nil }
      stub_const('MyHandler', handler)
      expect(Spree.hooks.for('testing.sample_workflow.point').size).to eq(1)
    end
  end

  describe 'emits' do
    it 'serializes through event_payload by convention, explicitly in the lambda' do
      workflow = build_workflow do
        argument :subject
        emit 'testing.finished', payload: -> { context.subject.event_payload.merge(extra: context.subject.class.name) }
      end

      record = create(:cart, store: @default_store)
      instance = workflow.new
      result = instance.call(subject: record)
      expect(result).to be_success
      event = instance.emitted_events.sole
      expect(event[:name]).to eq('testing.finished')
      expect(event[:payload][:id]).to eq(record.prefixed_id)
      expect(event[:payload][:extra]).to eq('Spree::Cart')
    end

    it 'collects declared events on success and exposes them' do
      workflow = build_workflow do
        argument :subject
        step :work, provides: [:artifact]
        emit 'testing.finished', payload: -> { { artifact: context.artifact } }
        def work = { artifact: 'done' }
      end

      instance = workflow.new
      result = instance.call(subject: 1)
      expect(result).to be_success
      expect(instance.emitted_events).to eq([{ name: 'testing.finished', payload: { artifact: 'done' } }])
    end

    it 'names the context class as the flow Context constant' do
      workflow = build_workflow do
        argument :subject
        step :noop
        def noop = nil
      end

      workflow.call(subject: 1)
      expect(workflow.const_get(:Context).instance_methods).to include(:subject)
    end

    it 'does not collect events on failure' do
      workflow = build_workflow do
        argument :subject
        step :work
        emit 'testing.finished', payload: -> { { subject: context.subject } }
        def work = failure('no')
      end

      instance = workflow.new
      expect(instance.call(subject: 1)).to be_failure
      expect(instance.emitted_events).to be_empty
    end
  end
end
