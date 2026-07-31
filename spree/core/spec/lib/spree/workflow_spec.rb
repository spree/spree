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

  describe 'the perform signature as the argument contract' do
    it 'raises Ruby argument errors for missing and unknown keywords' do
      workflow = build_workflow do
        def perform(subject:) = success(subject)
      end

      expect(workflow.call(subject: 1)).to be_success
      expect { workflow.call }.to raise_error(ArgumentError, /missing keyword: :subject/)
      expect { workflow.call(subject: 1, bogus: 2) }.to raise_error(ArgumentError, /unknown keyword: :bogus/)
    end

    it 'assigns parameters — defaults applied — to readers via bare super' do
      workflow = build_workflow do
        def perform(subject:, quantity: 2)
          super
          step :inspect_arguments
        end

        private

        def inspect_arguments = success([subject, quantity])
      end

      expect(workflow.call(subject: 'a').value).to eq(['a', 2])
      expect(workflow.call(subject: 'a', quantity: 5).value).to eq(['a', 5])
    end

    it 'wraps a bare perform return value in success' do
      workflow = build_workflow do
        def perform(subject:) = subject * 2
      end

      result = workflow.call(subject: 21)
      expect(result).to be_success
      expect(result.value).to eq(42)
    end
  end

  describe 'steps and control flow' do
    it 'aborts the flow when a step fails, skipping later steps' do
      ran = []
      workflow = build_workflow do
        define_method(:noted) { |name| ran << name }

        def perform(subject:)
          super
          step :first
          step :explode
          step :never
          success(subject)
        end

        private

        def first = noted(:first)
        def explode = failure(:exploded, 'boom')
        def never = noted(:never)
      end

      result = workflow.call(subject: 1)
      expect(result).to be_failure
      expect(result.error.to_s).to eq('boom')
      expect(ran).to eq([:first])
    end

    it 'cannot have its failure swallowed by a plain rescue in perform' do
      workflow = build_workflow do
        def perform(subject:)
          super
          step :explode
          success(subject)
        rescue StandardError
          success(:swallowed)
        end

        private

        def explode = failure(:exploded, 'boom')
      end

      expect(workflow.call(subject: 1)).to be_failure
    end

    it 'halts successfully with halt! and forbids it inside a transaction' do
      workflow = build_workflow do
        def perform(subject:)
          super
          halt!(:early) if subject == :halt
          ApplicationRecord.transaction { halt!(:inside) } if subject == :inside_txn
          success(:reached_end)
        end
      end

      halted = workflow.call(subject: :halt)
      expect(halted).to be_success
      expect(halted.value).to eq(:early)
      expect(workflow.call(subject: :run).value).to eq(:reached_end)
      expect { workflow.call(subject: :inside_txn) }
        .to raise_error(Spree::Workflow::ContractError, /halt! cannot be called inside a database transaction/)
    end
  end

  describe 'transactions and compensation' do
    it 'rolls back a plain transaction on failure and runs undos armed before it' do
      undo_log = []
      workflow = build_workflow do
        define_method(:undo_outside) { undo_log << :undone }

        def perform(product:)
          super
          step :outside_work, on_flow_failure: :undo_outside
          ApplicationRecord.transaction do
            step :rename
            step :explode
          end
          success(product)
        end

        private

        def outside_work = nil
        def rename = product.update!(name: 'Renamed')
        def explode = failure(:exploded, 'boom')
      end

      product = create(:product, name: 'Original')
      result = workflow.call(product: product)

      expect(result).to be_failure
      expect(product.reload.name).to eq('Original')
      expect(undo_log).to eq([:undone])
    end

    it 'does not run undos armed inside a transaction that rolled back' do
      undo_log = []
      workflow = build_workflow do
        define_method(:undo_created) { undo_log << :undone }

        def perform(product:)
          super
          ApplicationRecord.transaction do
            step :rename, on_flow_failure: :undo_created
            step :explode
          end
          success(product)
        end

        private

        def rename = product.update!(name: 'Renamed')
        def explode = failure(:exploded, 'boom')
      end

      expect(workflow.call(product: create(:product))).to be_failure
      expect(undo_log).to be_empty
    end

    it 'arms undos at commit and pops them in reverse on later exceptions' do
      undo_log = []
      workflow = build_workflow do
        define_method(:undo_first)  { undo_log << :first }
        define_method(:undo_second) { undo_log << :second }

        def perform(product:)
          super
          ApplicationRecord.transaction do
            step :committed_work, on_flow_failure: :undo_first
          end
          step :more_work, on_flow_failure: :undo_second
          step :explode
          success(product)
        end

        private

        def committed_work = product.update!(name: 'Renamed')
        def more_work = nil
        def explode = raise('io blew up')
      end

      expect { workflow.call(product: create(:product)) }.to raise_error('io blew up')
      expect(undo_log).to eq([:second, :first])
    end

    it 'tolerates a caller-level transaction around the whole run' do
      workflow = build_workflow do
        def perform(subject:)
          super
          external_step :charge
          halt!(:early)
        end

        private

        def charge = nil
      end

      result = nil
      ApplicationRecord.transaction { result = workflow.call(subject: 1) }
      expect(result).to be_success
      expect(result.value).to eq(:early)
    end

    it 'refuses external_step inside a database transaction' do
      workflow = build_workflow do
        def perform(subject:)
          super
          ApplicationRecord.transaction { external_step :charge }
          success(subject)
        end

        private

        def charge = nil
      end

      expect { workflow.call(subject: 1) }
        .to raise_error(Spree::Workflow::ContractError, /external_step charge must not run inside a database transaction/)
    end
  end

  describe 'hooks' do
    it 'dispatches handlers with the workflow instance and validates declarations' do
      workflow = build_workflow do
        hooks :after_produce
        attr_reader :artifact

        def perform(subject:)
          super
          step :produce
          run_hooks :after_produce
          success(artifact)
        end

        private

        def produce = @artifact = "made-from-#{subject}"
      end

      seen = nil
      Spree.hooks.register('testing.sample_workflow.after_produce') { |flow| seen = [flow.subject, flow.artifact] }
      workflow.call(subject: 1)

      expect(seen).to eq([1, 'made-from-1'])
      expect(Spree.hooks.validate!).to be(true)

      Spree.hooks.register('testing.sample_workflow.typo_hook', 'SomeHandler')
      expect { Spree.hooks.validate! }.to raise_error(Spree::Hooks::UnknownHookError, /declares no hook 'typo_hook'/)
    end

    it 'raises when dispatching a hook the class does not declare' do
      workflow = build_workflow do
        def perform(subject:)
          super
          run_hooks :never_declared
          success(subject)
        end
      end

      expect { workflow.call(subject: 1) }
        .to raise_error(Spree::Workflow::ContractError, /does not declare hook :never_declared/)
    end
  end

  describe 'with: collaborators' do
    it 'slices keyword arguments from the workflow readers for workflows and services' do
      collaborator_workflow = Class.new(Spree::Workflow) do
        def self.name = 'Spree::Testing::TripleWorkflow'
        def perform(base:) = success(base * 3)
      end
      stub_const('Spree::Testing::TripleWorkflow', collaborator_workflow)

      collaborator_service = Class.new do
        prepend Spree::ServiceModule::Base
        def call(base:)
          success(base + 1)
        end
      end
      stub_const('Spree::Testing::PlusOneService', collaborator_service)

      workflow = build_workflow do
        def perform(base:)
          super
          tripled = step :triple, with: -> { Spree::Testing::TripleWorkflow }
          plus_one = step :plus_one, with: -> { Spree::Testing::PlusOneService }
          success([tripled.value, plus_one.value])
        end
      end

      expect(workflow.call(base: 3).value).to eq([9, 4])
    end

    it 'propagates a collaborator failure' do
      failing = Class.new do
        prepend Spree::ServiceModule::Base
        def call(base:)
          failure(base, 'nope')
        end
      end
      stub_const('Spree::Testing::FailingService', failing)

      workflow = build_workflow do
        def perform(base:)
          super
          step :doomed, with: -> { Spree::Testing::FailingService }
          success(:never)
        end
      end

      result = workflow.call(base: 3)
      expect(result).to be_failure
      expect(result.error.to_s).to eq('nope')
    end
  end

  describe 'twins' do
    it 'maps a legacy vocabulary through a plain perform override' do
      parent = build_workflow do
        def perform(cart:)
          super
          success("carted-#{cart}")
        end
      end

      twin = Class.new(parent) do
        def self.name = 'Spree::Testing::TwinWorkflow'
        def perform(order:, **rest) = super(cart: order, **rest)
      end
      stub_const('Spree::Testing::TwinWorkflow', twin)

      expect(twin.call(order: 'x').value).to eq('carted-x')
    end
  end

  describe 'observability' do
    it 'instruments every step as step.spree_workflow' do
      events = []
      subscriber = ActiveSupport::Notifications.subscribe('step.spree_workflow') do |*, payload|
        events << payload.slice(:workflow, :step)
      end

      workflow = build_workflow do
        def perform(subject:)
          super
          step :one
          step :two
          success(subject)
        end

        private

        def one = nil
        def two = nil
      end
      workflow.call(subject: 1)

      expect(events).to eq([
        { workflow: 'testing.sample_workflow', step: :one },
        { workflow: 'testing.sample_workflow', step: :two }
      ])
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
  end
end
