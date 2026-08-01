module Spree
  module Checkout
    # Value object representing a custom checkout step registered via {Registry}.
    #
    # @example Register a loyalty step before payment
    #   Spree::Checkout::Registry.register_step(
    #     name: :loyalty,
    #     before: :payment,
    #     satisfied: ->(cart) { cart.loyalty_verified? },
    #     requirements: ->(cart) { [{ step: 'loyalty', field: 'loyalty_number', message: 'Enter loyalty number' }] }
    #   )
    class Step
      # @return [String] step name
      attr_reader :name

      # @return [String, nil] name of the checkout step this should be placed after
      attr_reader :after

      # @return [String, nil] name of the checkout step this should be placed before
      attr_reader :before

      # @param name [String, Symbol] unique step identifier
      # @param satisfied [Proc] lambda accepting a cart, returns true when the step is complete
      # @param requirements [Proc] lambda accepting a cart, returns Array of requirement hashes
      #   (+{ step:, field:, message: }+) describing what is still needed
      # @param applicable [Proc] lambda accepting a cart, returns true when this step applies
      #   (defaults to always applicable)
      # @param after [String, Symbol, nil] place this step after the named checkout step
      # @param before [String, Symbol, nil] place this step before the named checkout step
      def initialize(name:, satisfied:, requirements:, applicable: ->(_) { true }, after: nil, before: nil)
        @name = name.to_s
        @after = after&.to_s
        @before = before&.to_s
        @satisfied_proc = satisfied
        @requirements_proc = requirements
        @applicable_proc = applicable
      end

      # @param cart [Spree::Cart]
      # @return [Boolean] whether the step's conditions have been met
      def satisfied?(cart) = @satisfied_proc.call(cart)

      # @param cart [Spree::Cart]
      # @return [Array<Hash{Symbol => String}>] outstanding requirement hashes (+{ step:, field:, message: }+)
      def requirements(cart) = @requirements_proc.call(cart)

      # @param cart [Spree::Cart]
      # @return [Boolean] whether this step applies to the given cart
      def applicable?(cart) = @applicable_proc.call(cart)
    end
  end
end
