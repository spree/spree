module Spree
  module Workflows
    # Provides workflow hooks for extensibility.
    #
    # Hooks allow third-party code (extensions, initializers) to inject logic
    # at specific points within a workflow, with support for compensation (rollback).
    #
    # @example Defining hooks in a workflow
    #   class OrderFulfillmentWorkflow < Spree::Workflows::Base
    #     include Spree::Workflows::Hookable
    #
    #     workflow_id 'order_fulfillment'
    #
    #     step :validate_order do |input, context|
    #       # validation logic
    #     end
    #
    #     define_hook :after_order_validated
    #
    #     step :reserve_inventory do |input, context|
    #       # reservation logic
    #     end
    #
    #     define_hook :after_inventory_reserved
    #   end
    #
    # @example Registering a hook handler (in an initializer or extension)
    #   Spree::OrderFulfillmentWorkflow.hooks.after_order_validated do |context|
    #     # Run fraud check
    #     FraudService.check(context[:order])
    #   end.compensate do |context|
    #     # Undo fraud hold if later steps fail
    #     FraudService.release_hold(context[:order])
    #   end
    #
    # @example Hook with additional data access
    #   Spree::OrderFulfillmentWorkflow.hooks.after_inventory_reserved do |context|
    #     # Access workflow context
    #     order = context[:order]
    #     reserved_items = context[:reserved_items]
    #
    #     # Notify warehouse system
    #     WarehouseAPI.notify_reservation(order, reserved_items)
    #   end
    #
    module Hookable
      extend ActiveSupport::Concern

      included do
        class_attribute :defined_hooks, default: []
        class_attribute :hook_handlers, default: {}
      end

      class_methods do
        # Define a hook point in the workflow
        #
        # @param name [Symbol] the hook name
        # @return [void]
        def define_hook(name)
          self.defined_hooks = defined_hooks + [name.to_sym]
        end

        # Access the hooks DSL for registering handlers
        #
        # @return [HookRegistry]
        def hooks
          @hooks ||= HookRegistry.new(self)
        end

        # Register a hook handler
        #
        # @param hook_name [Symbol] the hook to attach to
        # @param handler [Proc] the handler block
        # @param compensation [Proc, nil] optional compensation block
        # @return [void]
        def register_hook_handler(hook_name, handler:, compensation: nil)
          unless defined_hooks.include?(hook_name.to_sym)
            raise ArgumentError, "Unknown hook '#{hook_name}'. Available hooks: #{defined_hooks.join(', ')}"
          end

          self.hook_handlers = hook_handlers.merge(
            hook_name.to_sym => HookHandler.new(
              name: hook_name,
              handler: handler,
              compensation: compensation
            )
          )
        end

        # Get handler for a specific hook
        #
        # @param hook_name [Symbol]
        # @return [HookHandler, nil]
        def hook_handler_for(hook_name)
          hook_handlers[hook_name.to_sym]
        end
      end

      # Execute a hook point during workflow execution
      #
      # @param hook_name [Symbol] the hook to execute
      # @param context [Context] the workflow context
      # @return [void]
      def execute_hook(hook_name, context)
        handler = self.class.hook_handler_for(hook_name)
        return unless handler

        handler.execute(context)
      end

      # Execute compensation for a hook
      #
      # @param hook_name [Symbol] the hook to compensate
      # @param context [Context] the workflow context
      # @return [void]
      def compensate_hook(hook_name, context)
        handler = self.class.hook_handler_for(hook_name)
        return unless handler

        handler.compensate(context)
      end
    end

    # DSL for registering hook handlers
    class HookRegistry
      def initialize(workflow_class)
        @workflow_class = workflow_class
      end

      # Dynamic method handling for hook registration
      #
      # @example
      #   hooks.after_order_validated do |context|
      #     # handler code
      #   end
      #
      def method_missing(hook_name, &block)
        if @workflow_class.defined_hooks.include?(hook_name.to_sym)
          HookBuilder.new(@workflow_class, hook_name, block)
        else
          super
        end
      end

      def respond_to_missing?(hook_name, include_private = false)
        @workflow_class.defined_hooks.include?(hook_name.to_sym) || super
      end
    end

    # Builder for fluent hook registration with compensation
    class HookBuilder
      def initialize(workflow_class, hook_name, handler)
        @workflow_class = workflow_class
        @hook_name = hook_name
        @handler = handler
        @compensation = nil

        # Register immediately (compensation can be added via chain)
        register!
      end

      # Add compensation logic
      #
      # @yield [context] compensation block
      # @return [self]
      def compensate(&block)
        @compensation = block
        register!
        self
      end

      private

      def register!
        @workflow_class.register_hook_handler(
          @hook_name,
          handler: @handler,
          compensation: @compensation
        )
      end
    end

    # Holds a hook's handler and compensation logic
    class HookHandler
      attr_reader :name, :handler, :compensation

      def initialize(name:, handler:, compensation: nil)
        @name = name.to_sym
        @handler = handler
        @compensation = compensation
      end

      # Execute the hook handler
      #
      # @param context [Context]
      # @return [Object] handler result
      def execute(context)
        return unless handler

        handler.call(context)
      rescue StandardError => e
        raise HookExecutionError.new(
          "Hook '#{name}' failed: #{e.message}",
          hook_name: name,
          original_error: e
        )
      end

      # Execute compensation
      #
      # @param context [Context]
      # @return [void]
      def compensate(context)
        return unless compensation

        compensation.call(context)
      rescue StandardError => e
        Rails.error.report(e, context: { hook_name: name, action: 'compensation' })
      end

      def compensatable?
        compensation.present?
      end
    end

    # Error raised when a hook execution fails
    class HookExecutionError < Error
      attr_reader :hook_name, :original_error

      def initialize(message, hook_name:, original_error: nil)
        @hook_name = hook_name
        @original_error = original_error
        super(message)
      end
    end
  end
end
