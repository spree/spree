module Spree
  module Checkout
    # Global registry for custom checkout steps and requirements.
    #
    # Provides a composable extension point so developers can add, remove, or
    # reorder checkout steps and attach extra requirements to existing steps —
    # all without subclassing or monkey-patching.
    #
    # Registered steps and requirements are evaluated by {Requirements} at
    # serialization time to produce the +requirements+ array on the Cart API.
    #
    # @example Add a custom step
    #   Spree::Checkout::Registry.register_step(
    #     name: :loyalty,
    #     before: :payment,
    #     satisfied: ->(order) { order.loyalty_verified? },
    #     requirements: ->(order) { [{ step: 'loyalty', field: 'loyalty_number', message: 'Required' }] }
    #   )
    #
    # @example Add a requirement to an existing step
    #   Spree::Checkout::Registry.add_requirement(
    #     step: :payment,
    #     field: :po_number,
    #     message: 'PO number is required',
    #     satisfied: ->(order) { order.po_number.present? }
    #   )
    #
    # @example Remove a step
    #   Spree::Checkout::Registry.remove_step(:loyalty)
    class Registry
      class << self
        # Register a new custom checkout step.
        #
        # @param name [String, Symbol] unique step identifier
        # @param satisfied [Proc] lambda accepting an order, returns true when step is complete
        # @param requirements [Proc] lambda accepting an order, returns Array of requirement hashes
        # @param options [Hash] additional options forwarded to {Step} (+:before+, +:after+, +:applicable+)
        # @return [Array<Step>] the updated steps list
        def register_step(name:, satisfied:, requirements:, **options)
          steps << Step.new(name: name, satisfied: satisfied, requirements: requirements, **options)
        end

        # Add an extra requirement to an existing checkout step.
        #
        # @param step [String, Symbol] checkout step this requirement belongs to
        # @param field [String, Symbol] field identifier
        # @param message [String] human-readable validation message
        # @param satisfied [Proc] lambda accepting an order, returns true when met
        # @param options [Hash] additional options forwarded to {Requirement} (+:applicable+)
        # @return [Array<Requirement>] the updated requirements list
        def add_requirement(step:, field:, message:, satisfied:, **options)
          requirements << Requirement.new(step: step, field: field, message: message, satisfied: satisfied, **options)
        end

        # Remove a previously registered step by name.
        #
        # @param name [String, Symbol] step name to remove
        # @return [Array<Step>] the updated steps list
        def remove_step(name)
          steps.reject! { |s| s.name == name.to_s }
        end

        # Remove a previously registered requirement by step and field.
        #
        # @param step [String, Symbol] checkout step the requirement belongs to
        # @param field [String, Symbol] field identifier
        # @return [Array<Requirement>] the updated requirements list
        def remove_requirement(step:, field:)
          requirements.reject! { |r| r.step == step.to_s && r.field == field.to_s }
        end

        # Returns steps sorted by +before+/+after+ constraints relative to the checkout flow.
        #
        # The sort order is derived from {Spree::Order.checkout_step_names} so it
        # stays in sync with any customizations to the checkout state machine.
        # Steps with +before:+/+after:+ anchors are ordered by the anchor's position;
        # steps without constraints are appended at the end.
        #
        # @return [Array<Step>] steps in display order
        def ordered_steps
          return steps if steps.empty?

          step_order = Spree::Order.checkout_step_names.map(&:to_s)
          positioned, unpositioned = steps.partition { |s| s.before || s.after }

          sorted = positioned.sort_by do |s|
            anchor = s.before || s.after
            idx = step_order.index(anchor)
            # before: inserts just before the anchor, after: just after
            idx ? (s.before ? idx - 0.5 : idx + 0.5) : Float::INFINITY
          end

          sorted + unpositioned
        end

        # @return [Array<Step>] all registered steps
        def steps = (@steps ||= [])

        # @return [Array<Requirement>] all registered requirements
        def requirements = (@requirements ||= [])

        # Clear all registered steps and requirements. Intended for testing.
        #
        # @return [void]
        def reset!
          @steps = []
          @requirements = []
        end
      end
    end
  end
end
