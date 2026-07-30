require 'spree/service_module'
require 'spree/hooks'

module Spree
  # Declared-step workflow base — the DSL from
  # docs/plans/6.0-service-workflows.md, reserved for the curated flows in
  # app/workflows/ (regular services stay plain ServiceModule classes).
  # Caller-compatible with ServiceModule (Callable.call, Result,
  # success/failure); adds declared argument contracts, real context
  # classes, explicit transaction grouping, per-step undo, extension hooks
  # and declared event emission.
  #
  #   class Spree::Carts::AddItem < Spree::Workflow
  #     workflow_key 'carts.add_item'
  #     argument :cart
  #     argument :variant
  #     argument :quantity, default: 1
  #     alias_argument order: :cart, deprecated: true
  #
  #     transaction do
  #       step :add_to_line_item, provides: [:line_item]
  #       run_hooks :after_item_added
  #     end
  #
  #     private
  #
  #     # Steps are zero-arg methods; arguments and provided keys read as
  #     # private methods (the #context accessor also remains available)
  #     def add_to_line_item
  #       { line_item: cart.line_items.find_or_initialize_by(variant: variant) }
  #     end
  #
  #     emit 'cart.item_added', payload: -> { { id: cart.prefixed_id } }
  #   end
  class Workflow
    prepend Spree::ServiceModule::Base

    class ContractError < StandardError; end

    Halt = Struct.new(:value)

    class << self
      attr_reader :declared_hooks

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@return_selector, return_selector)
        subclass.instance_variable_set(:@rescue_contracts, rescue_contracts.dup)
        subclass.instance_variable_set(:@flow_items, flow_items.dup)
        subclass.instance_variable_set(:@required_arguments, required_arguments.dup)
        subclass.instance_variable_set(:@optional_arguments, optional_arguments.dup)
        subclass.instance_variable_set(:@argument_aliases, argument_aliases.dup)
        subclass.instance_variable_set(:@argument_types, argument_types.dup)
        subclass.instance_variable_set(:@emits, emits.dup)
        subclass.instance_variable_set(:@declared_hooks, (declared_hooks || []).dup)
        subclass.instance_variable_set(:@context_keys, context_keys.dup)
      end

      def flow_items = @flow_items ||= []
      def required_arguments = @required_arguments ||= []
      def optional_arguments = @optional_arguments ||= {}
      def argument_aliases = @argument_aliases ||= {}
      def argument_types = @argument_types ||= {}
      def emits = @emits ||= []
      def context_keys = @context_keys ||= []

      # Dotted identity used for hook keys; derived from the class name
      # (Spree::Carts::AddItem => 'carts.add_item') unless set explicitly.
      def workflow_key(value = nil)
        @workflow_key = value.to_s if value
        @workflow_key ||= name.delete_prefix('Spree::').split('::').map(&:underscore).join('.')
      end

      REQUIRED = Object.new.freeze

      # One declared argument per line, ActiveJob/GraphQL-style. The
      # optional second positional declares a runtime-checked type: a
      # class/module, an array union (nil in the union means nilable), or
      # :boolean for [true, false]. Checked once at the call boundary —
      # ContractError in dev/test, log-warn in production. Never coerces.
      #
      #   argument :cart, Spree::Cart
      #   argument :quantity, Integer, default: 1
      #   argument :owner, [Spree::Cart, Spree::Order]
      def argument(name, type = nil, default: REQUIRED)
        name = name.to_sym
        argument_types[name] = type unless type.nil?
        if default.equal?(REQUIRED)
          @required_arguments = required_arguments | [name]
        else
          optional_arguments[name] = default
        end
        register_context_keys([name])
      end

      # alias_argument order: :cart, deprecated: true — accepts the legacy
      # keyword, warns when deprecated, maps onto the canonical argument.
      # Retires ad-hoc kwarg bridges and rewrite_input!.
      def alias_argument(deprecated: false, **mapping)
        mapping.each { |from, to| argument_aliases[from.to_sym] = { to: to.to_sym, deprecated: deprecated } }
      end

      def step(name, provides: [], if: nil, on_flow_failure: nil, with: nil, halt_with: nil)
        condition = binding.local_variable_get(:if)
        flow_items << { type: :step, name: name.to_sym, provides: Array(provides).map(&:to_sym),
                        if: condition, on_flow_failure: on_flow_failure&.to_sym, with: binding.local_variable_get(:with),
                        halt_with: halt_with&.to_sym, io: false,
                        transaction: @building_transaction }
        register_context_keys(Array(provides).map(&:to_sym) + [halt_with].compact.map(&:to_sym))
      end

      # External I/O — structurally forbidden inside a transaction block.
      def external_step(name, provides: [], if: nil, on_flow_failure: nil, halt_with: nil)
        raise ContractError, "external_step #{name} cannot be declared inside a transaction block" if @building_transaction

        condition = binding.local_variable_get(:if)
        flow_items << { type: :step, name: name.to_sym, provides: Array(provides).map(&:to_sym),
                        if: condition, on_flow_failure: on_flow_failure&.to_sym, with: nil,
                        halt_with: halt_with&.to_sym, io: true, transaction: nil }
        register_context_keys(Array(provides).map(&:to_sym) + [halt_with].compact.map(&:to_sym))
      end

      # transaction(lock: :cart) do ... end — steps inside share one
      # database transaction (optionally holding a row lock); rollback is
      # their compensation.
      def transaction(lock: nil, &block)
        group = { lock: lock&.to_sym }
        @building_transaction = group
        instance_eval(&block)
      ensure
        @building_transaction = nil
      end

      def run_hooks(name)
        (@declared_hooks ||= []) << name.to_sym
        flow_items << { type: :hook, name: name.to_sym, transaction: @building_transaction }
        Spree.hooks.register_workflow(workflow_key, self.name)
      end

      # Declared after-commit event. The payload lambda is explicit plain
      # Ruby — by convention it serializes through the record's
      # event_payload (the same V3 serializer path lifecycle events use),
      # so what feeds the event is visible at the declaration:
      #
      #   emit 'order.placed', payload: -> { order.event_payload.merge(notify_customer: order.notify_customer) }
      def emit(event_name, payload:)
        emits << { name: event_name.to_s, payload: payload }
      end

      # Declarative exception contract: convert matching exceptions raised
      # anywhere in the flow into failure Results (the block builds the
      # Result via the failure helper). Unmatched exceptions keep raising.
      #
      #   rescue_from ActiveRecord::RecordInvalid do |error|
      #     failure(cart, error.record.errors.full_messages.to_sentence)
      #   end
      def rescue_from(*exception_classes, &block)
        raise ArgumentError, 'rescue_from requires a block building the failure Result' if block.nil?

        exception_classes.each { |klass| rescue_contracts << { klass: klass, handler: block } }
      end

      def rescue_contracts = @rescue_contracts ||= []

      # Selects the successful Result value (a context key, or a lambda on
      # the context). Defaults to the context itself.
      def returns(key = nil, &block)
        @return_selector = block || key
      end

      def return_selector
        @return_selector
      end

      # @return [Array<Symbol>] context keys available at the given hook
      def hook_contract(hook_name)
        available = required_arguments + optional_arguments.keys
        flow_items.each do |item|
          return available.uniq if item[:type] == :hook && item[:name] == hook_name.to_sym

          available += item[:provides] if item[:type] == :step
        end
        raise Spree::Hooks::UnknownHookError, "#{name} declares no hook '#{hook_name}'"
      end

      # Real context class with defined readers — the editor story depends
      # on these being actual methods (never method_missing). Named as the
      # flow's Context constant (Spree::Carts::AddItem::Context) so YARD
      # references and the generated RBS have a real type to point at.
      def context_class
        @context_class ||= begin
          klass = Workflow.build_context_class(context_keys)
          remove_const(:Context) if const_defined?(:Context, false)
          const_set(:Context, klass)
        end
      end

      def build_context_class(keys)
        Class.new do
          define_method(:initialize) { |values| @values = values }

          keys.each do |key|
            define_method(key) { @values[key] }
          end

          define_method(:[]) { |key| @values[key.to_sym] }
          define_method(:to_h) { @values.dup }
          define_method(:deconstruct_keys) { |requested| requested.nil? ? @values.dup : @values.slice(*requested) }
          define_method(:key?) { |key| @values.key?(key.to_sym) }

          define_method(:merge!) do |hash|
            @values.merge!(hash.transform_keys(&:to_sym))
            self
          end

          def method_missing(name, *args)
            raise NoMethodError,
                  "Unknown context key :#{name} — available: #{@values.keys.join(', ')}"
          end

          def respond_to_missing?(_name, _include_private = false)
            false
          end
        end
      end

      # Keys the reader-definition must never shadow — the DSL's own API.
      def reserved_context_key?(key)
        @reserved_context_keys ||= (Workflow.instance_methods(false) +
          Workflow.private_instance_methods(false) +
          Spree::ServiceModule::Base.instance_methods(false)).to_set
        @reserved_context_keys.include?(key)
      end

      private

      # Arguments and provided keys become private zero-arg readers on the
      # service (ActiveInteraction-style), so step bodies read +cart+, not
      # +context.cart+. An author-defined method of the same name wins; a
      # collision with the Spree::Workflow API itself is a definition error.
      def register_context_keys(keys)
        keys.each do |key|
          raise ContractError, "#{name}: context key :#{key} collides with the Spree::Workflow API" if Workflow.reserved_context_key?(key)

          unless method_defined?(key, false) || private_method_defined?(key, false)
            define_method(key) { @context[key] }
            private key
          end
        end
        @context_keys = context_keys | keys
        @context_class = nil
      end
    end

    attr_reader :context

    # Events collected by emit declarations; published after all
    # transactions commit. Exposed for specs.
    attr_reader :emitted_events

    def call(**kwargs)
      kwargs = resolve_aliases(kwargs)
      validate_arguments!(kwargs)

      values = self.class.optional_arguments.merge(kwargs)
      @context = self.class.context_class.new(values)
      @undo_stack = []
      @emitted_events = []

      result = execute_flow
      result = success(default_return_value) unless result.is_a?(Spree::ServiceModule::Result)

      if result.success?
        collect_emits
        publish_emitted_events
      end

      result
    rescue StandardError => e
      run_undo_stack!
      contract = self.class.rescue_contracts.find { |entry| e.is_a?(entry[:klass]) }
      raise if contract.nil?

      handler = contract[:handler]
      outcome = handler.arity == 1 ? instance_exec(e, &handler) : instance_exec(e, @context, &handler)
      raise unless outcome.is_a?(Spree::ServiceModule::Result)

      outcome
    end

    private

    def default_return_value
      selector = self.class.return_selector
      case selector
      when nil then @context
      when Symbol then @context[selector]
      when Proc then exec_in_service(selector)
      end
    end

    # DSL lambdas (if:, returns, emit payloads) run in the service instance
    # and read the #context accessor; legacy one-arg lambdas still receive
    # the context.
    def exec_in_service(block)
      block.arity.zero? ? instance_exec(&block) : instance_exec(@context, &block)
    end

    def resolve_aliases(kwargs)
      self.class.argument_aliases.each do |from, config|
        next unless kwargs.key?(from)

        if config[:deprecated]
          Spree::Deprecation.warn(
            "Calling #{self.class.name} with #{from}: is deprecated and will be removed in Spree 6.1. Pass #{config[:to]}: instead."
          )
        end
        legacy_value = kwargs.delete(from)
        kwargs[config[:to]] = legacy_value if kwargs[config[:to]].nil?
      end
      kwargs
    end

    def validate_arguments!(kwargs)
      unknown = kwargs.keys.map(&:to_sym) - self.class.context_keys
      if unknown.any?
        message = "#{self.class.name}: unknown argument #{unknown.join(', ')} (accepts: #{(self.class.required_arguments + self.class.optional_arguments.keys).join(', ')})"
        raise ContractError, message unless Rails.env.production?

        Rails.logger.warn(message)
      end

      missing = self.class.required_arguments.select { |key| !kwargs.key?(key) || kwargs[key].nil? }
      raise ContractError, "#{self.class.name}: missing required argument #{missing.join(', ')}" if missing.any?

      validate_argument_types!(kwargs)
    end

    # Presence is the required-check's job — nil supplied values are skipped
    # here, so optional arguments are nilable without declaring it.
    def validate_argument_types!(kwargs)
      self.class.argument_types.each do |key, type|
        value = kwargs[key]
        next if value.nil? || type_matches?(value, type)

        message = "#{self.class.name}: expected #{key} to be #{describe_type(type)}, got #{value.class.name}"
        raise ContractError, message unless Rails.env.production?

        Rails.logger.warn(message)
      end
    end

    def type_matches?(value, type)
      case type
      when Array then type.any? { |member| type_matches?(value, member) }
      when :boolean then value == true || value == false
      when nil then value.nil?
      when Module then value.is_a?(type)
      else false
      end
    end

    def describe_type(type)
      case type
      when Array then type.map { |member| describe_type(member) }.join(' | ')
      when :boolean then 'boolean'
      when nil then 'nil'
      else type.name
      end
    end

    def execute_flow
      items = self.class.flow_items
      index = 0

      while index < items.length
        item = items[index]

        if (group = item[:transaction])
          group_items = []
          group_items << items[index] and index += 1 while index < items.length && items[index][:transaction].equal?(group)

          result = run_transaction_group(group, group_items)
        else
          result = run_item(item, compensable: true)
          index += 1
        end

        return result if result.is_a?(Spree::ServiceModule::Result) || result.is_a?(Halt)
      end

      nil
    rescue StandardError
      raise
    ensure
      # Halt is success — unwrap for the caller.
    end

    def run_transaction_group(group, group_items)
      completed_in_group = []
      outcome = nil

      run_in_lock(group[:lock]) do
        ApplicationRecord.transaction do
          group_items.each do |item|
            outcome = run_item(item, compensable: false)
            if outcome.is_a?(Spree::ServiceModule::Result)
              raise ActiveRecord::Rollback if outcome.failure?

              break
            end
            break if outcome.is_a?(Halt)

            completed_in_group << item
          end
        end
      end

      if outcome.is_a?(Spree::ServiceModule::Result) && outcome.failure?
        # The group rolled back — undo previously committed work.
        run_undo_stack!
        return outcome
      end

      # Once the group committed, its compensable steps join the stack.
      completed_in_group.each do |item|
        @undo_stack << item[:on_flow_failure] if item[:on_flow_failure]
      end

      outcome
    end

    def run_in_lock(lock_key, &block)
      return yield if lock_key.nil?

      @context[lock_key].with_lock(&block)
    end

    def run_item(item, compensable:)
      case item[:type]
      when :hook
        Spree.hooks.dispatch("#{self.class.workflow_key}.#{item[:name]}", @context)
        nil
      when :step
        run_step(item, compensable: compensable)
      end
    end

    def run_step(item, compensable:)
      return nil if item[:if] && !exec_in_service(item[:if])

      outcome =
        if item[:with]
          callable = instance_exec(&item[:with])
          callable.call(**@context.to_h.slice(*callable_kwargs(callable)))
        else
          send(item[:name])
        end

      case outcome
      when Spree::ServiceModule::Result
        if outcome.failure?
          run_undo_stack!
          return outcome
        end
        merge_step_output(item, outcome.value) if outcome.value.is_a?(Hash)
      when Hash
        merge_step_output(item, outcome)
      end

      @undo_stack << item[:on_flow_failure] if compensable && item[:on_flow_failure]

      if item[:halt_with] && @context.key?(item[:halt_with]) && @context[item[:halt_with]]
        return success(@context[item[:halt_with]])
      end

      nil
    end

    # provides: is the step's write schema — a step declaring no outputs
    # writes nothing, so bodies can end on any expression (no defensive
    # trailing nils) without incidental hashes polluting the context.
    def merge_step_output(item, hash)
      allowed = item[:provides] + [item[:halt_with]].compact
      return if allowed.empty?

      extras = hash.keys.map(&:to_sym) - allowed
      if extras.any?
        message = "#{self.class.name}##{item[:name]} returned undeclared keys #{extras.join(', ')} (declared provides: #{item[:provides].join(', ')})"
        raise ContractError, message unless Rails.env.production?

        Rails.logger.warn(message)
      end
      @context.merge!(hash)
    end

    def callable_kwargs(callable)
      if callable.is_a?(Class) && callable < Spree::Workflow
        return callable.required_arguments + callable.optional_arguments.keys + callable.argument_aliases.keys
      end

      target = callable.respond_to?(:new) ? callable.instance_method(:call) : callable.method(:call)
      # Skip the prepended wrappers (ServiceModule::Base / Service) to read
      # the signature the author actually wrote.
      while target.respond_to?(:owner) && [Spree::ServiceModule::Base, Spree::Workflow].include?(target.owner) && target.super_method
        target = target.super_method
      end
      params = target.parameters
      return @context.to_h.keys if params.any? { |type, _| type == :keyrest }

      params.filter_map { |type, name| name if [:key, :keyreq].include?(type) }
    end

    def run_undo_stack!
      return if @undo_stack.nil?

      @undo_stack.reverse_each do |compensation|
        send(compensation)
      rescue StandardError => e
        Rails.error.report(e, context: { workflow: self.class.workflow_key }, source: 'spree.workflow')
      end
      @undo_stack = []
    end

    def collect_emits
      self.class.emits.each do |declaration|
        payload =
          case declaration[:payload]
          when Proc then exec_in_service(declaration[:payload])
          when Symbol then send(declaration[:payload])
          end
        @emitted_events << { name: declaration[:name], payload: payload }
      end
    end

    def publish_emitted_events
      events = @emitted_events
      return if events.empty?

      publish = -> { events.each { |event| Spree::Events.publish(event[:name], event[:payload]) } }

      # Non-joinable transactions are test fixtures — deferring behind one
      # would postpone past the example's rollback, so publish immediately.
      if ApplicationRecord.connection.transaction_open? && ApplicationRecord.connection.current_transaction.joinable?
        ActiveRecord.after_all_transactions_commit(&publish)
      else
        publish.call
      end
    end
  end
end
