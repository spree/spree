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

    # ActiveModel::Errors asks its base for these when turning a symbolic
    # error into a message — a workflow is not a model, but it answers the
    # same three questions so `errors.add(:field, :symbol)` resolves against
    # the workflow's own i18n scope.
    extend ActiveModel::Naming
    extend ActiveModel::Translation

    class << self
      attr_reader :declared_hooks

      # Anonymous test doubles have no name to derive a model name from.
      def model_name
        @model_name ||= ActiveModel::Name.new(self, nil, name || 'Workflow')
      end

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
      #
      # Note for workflow authors: inside #perform, a parameter name is a
      # local variable and shadows the reader, so a step that reassigns the
      # ivar (`@product = ...`) is invisible to `success(product)` further
      # down. Name derived state differently from the parameter that seeded
      # it — Carts::AddItem takes `variant` and exposes `line_item`.
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

      ActiveSupport::Notifications.instrument(
        'perform.spree_workflow', workflow: self.class.workflow_key
      ) do |payload|
        outcome = perform(**kwargs)
        result = outcome.is_a?(Spree::ServiceModule::Result) ? outcome : success(outcome)
        payload[:outcome] = result.success? ? 'success' : 'failure'
        result
      rescue Halted => halted
        payload[:outcome] = 'success'
        success(halted.value)
      rescue FailureSignal => signal
        payload[:outcome] = 'failure'
        run_undo_stack!
        signal.result
      rescue StandardError
        payload[:outcome] = 'error'
        run_undo_stack!
        raise
      end
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

    # Rejections a handler collected, rendered by the API through the same
    # path as model validation errors — an extension veto and a failed
    # `validates` produce the same 422 shape.
    #
    # @return [ActiveModel::Errors]
    def errors
      @errors ||= ActiveModel::Errors.new(self)
    end

    delegate :model_name, to: :class

    # ActiveModel::Errors reads attribute values off its base when
    # interpolating a message; a workflow's "attributes" are its argument
    # readers, and an error on an attribute the workflow doesn't expose
    # (:base, or a field name belonging to the record) must not raise.
    def read_attribute_for_validation(attribute)
      respond_to?(attribute) ? public_send(attribute) : nil
    end

    # Vetoes the flow from a hook handler — the extension-facing twin of
    # failure(...). Same mechanics (raises, unwinds the undo stack, rolls
    # back an open transaction); the distinct name keeps "an extension
    # rejected this" legible against "this step failed" at the call site.
    # Public because handlers call it on the dispatched instance.
    #
    # Preferred form is argument-less, after adding symbolic errors:
    #
    #   workflow.errors.add(:quantity, :purchase_limit_exceeded, message: '…')
    #   workflow.reject!
    #
    # @param message [String, Symbol, nil] legacy flat rejection; recorded on
    #   :base so it renders through the same field-error payload
    # @param value [Object, nil] subject of the failure Result
    def reject!(message = nil, value = nil)
      errors.add(:base, message) if message.present?
      failure(value, errors)
    end

    private

    def step(name, with: nil, on_flow_failure: nil, external: false)
      outcome = ActiveSupport::Notifications.instrument(
        'step.spree_workflow', workflow: self.class.workflow_key, step: name, external: external
      ) do |payload|
        result = with ? call_collaborator(instance_exec(&with)) : send(name)
        payload[:outcome] = result.is_a?(Spree::ServiceModule::Result) && result.failure? ? 'failure' : 'success'
        result
      end

      raise FailureSignal.new(outcome) if outcome.is_a?(Spree::ServiceModule::Result) && outcome.failure?

      arm_undo(on_flow_failure) if on_flow_failure
      outcome
    end

    # Gateway/network I/O — must never share a database transaction the
    # workflow opened (a caller-level wrapping transaction is the caller's
    # responsibility). Marks the notification payload `external: true` so
    # tracing subscribers render it as an outbound (client) call.
    def external_step(name, **options)
      raise ContractError, "external_step #{name} must not run inside a database transaction" if in_workflow_transaction?

      step(name, external: true, **options)
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

      key = "#{self.class.workflow_key}.#{name}"
      ActiveSupport::Notifications.instrument(
        'hooks.spree_workflow',
        workflow: self.class.workflow_key, hook: name.to_sym, handler_count: Spree.hooks.handler_count(key)
      ) do
        Spree.hooks.dispatch(key, self)
      end
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
