require 'spree/service_module'
require 'spree/hooks'

module Spree
  # Workflow — Tier 2 of the services doctrine
  # (docs/plans/6.0-service-workflows.md): named steps inside a plain
  # #perform method, the ActiveJob::Continuable shape.
  #
  #   class Spree::Orders::Cancel < Spree::Workflow
  #     hooks :after_cancel
  #     attr_reader :cancellation          # derived state hook handlers may read
  #
  #     # @param order [Spree::Order] the order to cancel
  #     def perform(order:, canceler: nil, reason: 'other')
  #       super
  #
  #       step :ensure_cancellable
  #       ApplicationRecord.transaction do
  #         step :record_cancellation
  #         run_hooks :after_cancel
  #       end
  #       external_step :settle_payments
  #       order.publish_event('order.canceled')
  #       success(order.reload)
  #     rescue ActiveRecord::RecordInvalid
  #       failure(order)
  #     end
  #   end
  #
  # The #perform signature IS the argument contract: Ruby itself raises on
  # missing or unknown keywords, YARD documents it. A bare `super` first
  # assigns every parameter — defaults applied — to an instance variable
  # with a public reader, so step bodies and hook handlers read plain
  # methods. Everything else is ordinary Rails: plain transactions and
  # locks, plain `if`, plain `rescue`, `publish_event` for announcements.
  #
  # The workflow vocabulary is five words. `step :name` runs the method of
  # that name (instrumented as 'step.spree_workflow'); `on_flow_failure:`
  # names its undo, armed when the surrounding transaction commits and run
  # in reverse when a later step fails; `with:` delegates the step to a
  # collaborator resolved from the lambda, its keyword arguments sliced
  # from this workflow's readers. `external_step` marks gateway/network
  # I/O and refuses to run inside a database transaction. `run_hooks`
  # dispatches a declared extension point (see .hooks) with the workflow
  # instance. `failure(...)` aborts the flow from anywhere — it raises
  # internally, so an open plain transaction rolls back naturally — and
  # `halt!(value)` is its successful twin (outside transactions only).
  class Workflow
    prepend Spree::ServiceModule::Base

    class ContractError < StandardError; end

    # Internal control flow — Exception, not StandardError (the ActiveJob
    # Continuation::Interrupt precedent), so a plain `rescue` inside
    # #perform can't swallow it.
    class FailureSignal < Exception # rubocop:disable Lint/InheritException
      attr_reader :result

      def initialize(result)
        @result = result
        super('workflow failure')
      end
    end

    class Halted < Exception # rubocop:disable Lint/InheritException
      attr_reader :value

      def initialize(value)
        @value = value
        super('workflow halted')
      end
    end

    # failure(...) must abort the flow, but the prepended ServiceModule
    # helper sits ahead of this class in the lookup chain — this module
    # sits ahead of both, builds the Result via super and raises it.
    module ControlFlow
      def failure(value = nil, error = nil)
        raise FailureSignal.new(super)
      end
    end
    prepend ControlFlow

    class << self
      attr_reader :declared_hooks

      # A subclass inherits the parent's declared hooks but dispatches them
      # under its OWN key — Spree::Orders::AddItem fires
      # 'orders.add_item.validate', not the cart key — so it registers
      # itself too, otherwise Spree.hooks.validate! rejects registrations
      # against a twin's perfectly valid hook.
      def inherited(subclass)
        super
        inherited_hooks = (declared_hooks || []).dup
        subclass.instance_variable_set(:@declared_hooks, inherited_hooks)
        Spree.hooks.register_workflow(subclass.workflow_key, subclass.name) if inherited_hooks.any? && subclass.name
      end

      # Dotted identity used for hook keys and instrumentation; derived
      # from the class name (Spree::Carts::AddItem => 'carts.add_item')
      # unless set explicitly.
      def workflow_key(value = nil)
        @workflow_key = value.to_s if value
        @workflow_key ||= name.delete_prefix('Spree::').split('::').map(&:underscore).join('.')
      end

      # Declares the extension points this workflow dispatches via
      # run_hooks. Class-level so Spree.hooks.validate! can fail boot on
      # registrations against hooks that don't exist.
      def hooks(*names)
        @declared_hooks = (declared_hooks || []) | names.map(&:to_sym)
        Spree.hooks.register_workflow(workflow_key, self.name)
      end

      # Public readers for #perform's parameters, memoized per class. An
      # author-defined method of the same name wins.
      def define_argument_readers(names)
        @argument_readers ||= {}
        names.each do |name|
          next if @argument_readers[name]

          @argument_readers[name] = true
          next if method_defined?(name) || private_method_defined?(name)

          define_method(name) { instance_variable_get(:"@#{name}") }
        end
      end
    end

    # Bare `super` from the subclass's #perform lands here with the
    # parameter values as currently bound — defaults applied — and turns
    # each into an ivar + public reader.
    def perform(**arguments)
      arguments.each { |name, value| instance_variable_set(:"@#{name}", value) }
      self.class.define_argument_readers(arguments.keys)
    end

    def call(**kwargs)
      @undo_stack = []
      @outer_transaction_depth = ApplicationRecord.connection.open_transactions
      outcome = perform(**kwargs)
      outcome.is_a?(Spree::ServiceModule::Result) ? outcome : success(outcome)
    rescue Halted => halted
      success(halted.value)
    rescue FailureSignal => signal
      run_undo_stack!
      signal.result
    rescue StandardError
      run_undo_stack!
      raise
    end

    # Successful early exit from anywhere — the caller receives
    # success(value). Not from inside a transaction the workflow itself
    # opened: there is nothing committed to halt with (use failure to
    # roll back). A transaction the caller wrapped around the whole run
    # is theirs to commit and doesn't count.
    def halt!(value)
      raise ContractError, 'halt! cannot be called inside a database transaction' if in_workflow_transaction?

      raise Halted.new(value)
    end

    # Vetoes the flow from a hook handler — the extension-facing twin of
    # failure(...). Same mechanics (raises, unwinds the undo stack, rolls
    # back an open transaction); the distinct name keeps "an extension
    # rejected this" legible against "this step failed" at the call site.
    # Public because handlers call it on the dispatched instance.
    #
    # @param message [String, Symbol] surfaced as the failure Result's error
    # @param value [Object, nil] subject of the failure Result
    def reject!(message, value = nil)
      failure(value, message)
    end

    private

    def step(name, with: nil, on_flow_failure: nil)
      outcome = ActiveSupport::Notifications.instrument(
        'step.spree_workflow', workflow: self.class.workflow_key, step: name
      ) do
        with ? call_collaborator(instance_exec(&with)) : send(name)
      end

      raise FailureSignal.new(outcome) if outcome.is_a?(Spree::ServiceModule::Result) && outcome.failure?

      arm_undo(on_flow_failure) if on_flow_failure
      outcome
    end

    # Gateway/network I/O — must never share a database transaction the
    # workflow opened (a caller-level wrapping transaction is the caller's
    # responsibility).
    def external_step(name, **options)
      raise ContractError, "external_step #{name} must not run inside a database transaction" if in_workflow_transaction?

      step(name, **options)
    end

    # Dispatches every handler registered for this extension point with
    # the workflow instance — argument readers plus whatever the workflow
    # exposes via attr_reader are the handler's contract.
    #
    # @return [Hash] the deep-merged hashes handlers returned. Context hooks
    #   consume it (`context = run_hooks(:set_pricing_context)`); lifecycle
    #   hooks ignore it and validate handlers abort via #reject! instead.
    def run_hooks(name)
      unless self.class.declared_hooks&.include?(name.to_sym)
        raise ContractError, "#{self.class.name} does not declare hook :#{name} — add `hooks :#{name}` to the class"
      end

      Spree.hooks.dispatch("#{self.class.workflow_key}.#{name}", self)
    end

    # Undo methods arm when the workflow-opened transaction around their
    # step commits — inside a rolled-back transaction the rollback already
    # was the undo.
    def arm_undo(name)
      if in_workflow_transaction?
        ApplicationRecord.current_transaction.after_commit { @undo_stack << name.to_sym }
      else
        @undo_stack << name.to_sym
      end
    end

    def run_undo_stack!
      return if @undo_stack.nil?

      @undo_stack.reverse_each do |undo|
        send(undo)
      rescue StandardError => e
        Rails.error.report(e, context: { workflow: self.class.workflow_key }, source: 'spree.workflow')
      end
      @undo_stack = []
    end

    # A transaction opened during this run (fixture wrappers and
    # caller-level transactions sit at or below the baseline).
    def in_workflow_transaction?
      ApplicationRecord.connection.open_transactions > (@outer_transaction_depth || 0)
    end

    # Calls a with: collaborator, slicing its keyword arguments from this
    # workflow's readers. Workflow collaborators declare their contract on
    # #perform; ServiceModule collaborators on the #call the author wrote
    # (behind the prepended wrappers).
    def call_collaborator(callable)
      wanted = collaborator_keywords(callable)
      arguments = wanted.select { |name| respond_to?(name) }.index_with { |name| public_send(name) }
      callable.call(**arguments)
    end

    def collaborator_keywords(callable)
      target =
        if callable.is_a?(Class) && callable < Spree::Workflow
          callable.instance_method(:perform)
        elsif callable.respond_to?(:new)
          method = callable.instance_method(:call)
          method = method.super_method while [Spree::ServiceModule::Base, ControlFlow].include?(method.owner) && method.super_method
          method
        else
          callable.method(:call)
        end

      target.parameters.filter_map { |type, name| name if [:key, :keyreq].include?(type) }
    end
  end
end
